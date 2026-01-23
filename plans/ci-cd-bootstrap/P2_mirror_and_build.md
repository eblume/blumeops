# Phase 2: Mirror Forgejo & Create Build Workflow

**Goal**: Mirror upstream Forgejo to forge and create a workflow that builds it from source

**Status**: Planning

**Prerequisites**: [Phase 1](P1_enable_actions.md) complete (Actions enabled, runner deployed)

---

## Current State

- Forgejo Actions enabled with runner in k8s
- Upstream Forgejo at https://codeberg.org/forgejo/forgejo
- No local mirror yet

---

## Step 1: Mirror Upstream Forgejo

### 1.1 User Action: Create Mirror on Forge

**Manual step** (hairpinning doesn't work from indri):

1. Go to https://forge.tail8d86e.ts.net
2. Click "+" → "New Migration"
3. Select "Gitea" as clone source
4. URL: `https://codeberg.org/forgejo/forgejo.git`
5. Repository name: `forgejo`
6. Check "This repository will be a mirror"
7. Click "Migrate Repository"

### 1.2 Clone Mirror Locally

```bash
git clone ssh://forgejo@forge.tail8d86e.ts.net/eblume/forgejo.git ~/code/3rd/forgejo
cd ~/code/3rd/forgejo
```

---

## Step 2: Understand Forgejo Build Process

### 2.1 Build Requirements

From Forgejo's `Makefile` and docs:

- **Go**: 1.23+ (check `go.mod` for exact version)
- **Node.js**: 20+ (for frontend)
- **Make**: GNU Make
- **Git**: For version embedding

### 2.2 Build Commands

```bash
# Install frontend dependencies and build
make deps-frontend
make frontend

# Build backend
TAGS="bindata sqlite sqlite_unlock_notify" make backend

# Or all-in-one
TAGS="bindata sqlite sqlite_unlock_notify" make build
```

### 2.3 Output

Binary at `gitea` (yes, the binary is still named `gitea` for compatibility).

---

## Step 3: Create Build Workflow

### 3.1 SSH Deploy Key for Runner

The runner needs SSH access to indri to deploy the binary.

**Generate key on gilbert**:
```bash
ssh-keygen -t ed25519 -C "forgejo-runner-deploy" -f ~/.ssh/forgejo-runner-deploy
```

**Add public key to indri's authorized_keys**:
```bash
cat ~/.ssh/forgejo-runner-deploy.pub | ssh indri 'cat >> ~/.ssh/authorized_keys'
```

**Store private key in 1Password** (blumeops vault) as "Forgejo Runner Deploy Key"

**Add to k8s as secret**:

Create `argocd/manifests/forgejo-runner/secret-ssh.yaml.tpl`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-runner-ssh
  namespace: forgejo-runner
type: Opaque
stringData:
  id_ed25519: |
    op://blumeops/<deploy-key-item>/private-key
  known_hosts: |
    indri.tail8d86e.ts.net ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxx
```

Get indri's host key:
```bash
ssh-keyscan indri.tail8d86e.ts.net 2>/dev/null | grep ed25519
```

### 3.2 Create Workflow File

Create `.forgejo/workflows/build.yml` in the forgejo mirror repo:

```yaml
name: Build Forgejo

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      deploy:
        description: 'Deploy to indri after build'
        required: false
        default: 'true'
        type: boolean

env:
  GOPROXY: "https://proxy.golang.org,direct"
  CGO_ENABLED: "1"
  TAGS: "bindata sqlite sqlite_unlock_notify"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history for version

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version-file: 'go.mod'

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Get version
        id: version
        run: |
          if [[ "${{ github.ref }}" == refs/tags/* ]]; then
            VERSION="${{ github.ref_name }}"
          else
            VERSION="$(git describe --tags --always)-dev"
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "Building version: $VERSION"

      - name: Build frontend
        run: |
          make deps-frontend
          make frontend

      - name: Build backend
        run: |
          TAGS="${{ env.TAGS }}" make backend
          ./gitea --version

      - name: Rename binary
        run: |
          mv gitea forgejo-${{ steps.version.outputs.version }}-darwin-arm64
          ls -la forgejo-*

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: forgejo-${{ steps.version.outputs.version }}-darwin-arm64
          path: forgejo-${{ steps.version.outputs.version }}-darwin-arm64

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && github.event.inputs.deploy == 'true')
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: forgejo-${{ needs.build.outputs.version }}-darwin-arm64

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          echo "${{ secrets.DEPLOY_KNOWN_HOSTS }}" > ~/.ssh/known_hosts

      - name: Deploy to indri
        run: |
          BINARY="forgejo-*-darwin-arm64"
          chmod +x $BINARY

          # Copy binary to indri
          scp $BINARY erichblume@indri.tail8d86e.ts.net:~/.local/bin/forgejo-new

          # Atomic swap and restart
          ssh erichblume@indri.tail8d86e.ts.net << 'EOF'
            set -e
            cd ~/.local/bin

            # Verify the new binary runs
            ./forgejo-new --version

            # Stop current service
            launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist 2>/dev/null || true

            # Atomic swap
            mv forgejo forgejo-old 2>/dev/null || true
            mv forgejo-new forgejo

            # Start new service
            launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist

            # Verify it's running
            sleep 5
            curl -sf http://localhost:3001/api/v1/version || exit 1

            echo "Deploy successful!"
            ./forgejo --version
          EOF
```

### 3.3 Add Repository Secrets

In Forgejo, go to the forgejo repo → Settings → Actions → Secrets:

1. **DEPLOY_SSH_KEY**: Private key from 1Password
2. **DEPLOY_KNOWN_HOSTS**: Output of `ssh-keyscan indri.tail8d86e.ts.net`

---

## Step 4: Build Cross-Platform Consideration

**Important**: The runner runs Linux containers, but indri is macOS ARM64.

**Options**:

### Option A: Cross-compile (Simpler, may have issues)

Add to build job:
```yaml
env:
  GOOS: darwin
  GOARCH: arm64
```

CGO cross-compilation is tricky. May need to disable CGO or use a cross-compiler.

### Option B: Build on macOS (More reliable)

Run a macOS runner on indri itself (not in k8s).

```bash
# Install forgejo-runner on indri via mise
ssh indri 'mise use forgejo-runner'

# Register as a macOS runner
ssh indri 'forgejo-runner register --labels "macos-arm64:host" ...'
```

Then workflow uses:
```yaml
runs-on: macos-arm64
```

**Recommendation**: Option B is more reliable for native macOS builds. Consider deploying a runner directly on indri for macOS-specific builds.

---

## Step 5: Test the Build

### 5.1 Manual Workflow Dispatch

1. Go to https://forge.tail8d86e.ts.net/eblume/forgejo/actions
2. Select "Build Forgejo" workflow
3. Click "Run workflow"
4. Set deploy=false for first test
5. Monitor the run

### 5.2 Verify Artifact

Download the artifact from the workflow run and verify it's a valid binary:
```bash
# If downloaded to gilbert
file forgejo-*-darwin-arm64
# Should show: Mach-O 64-bit executable arm64
```

---

## Alternative: Build on Gilbert, Deploy via CI

If cross-compilation proves difficult, consider a hybrid approach:

1. **Build on gilbert** (has Go, Node, is macOS ARM64)
2. **CI just deploys** the built binary

Workflow in blumeops repo:
```yaml
name: Deploy Forgejo

on:
  workflow_dispatch:
    inputs:
      binary_path:
        description: 'Path to binary on gilbert'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # Fetch binary from gilbert and deploy to indri
      # (requires SSH access to both)
```

This is less elegant but more pragmatic for macOS targets.

---

## Verification Checklist

- [ ] Forgejo mirrored to forge
- [ ] SSH deploy key created and stored in 1Password
- [ ] Deploy key added to indri authorized_keys
- [ ] SSH secret added to k8s
- [ ] Workflow file created in forgejo mirror
- [ ] Repository secrets configured
- [ ] Test build completes successfully
- [ ] Binary is valid macOS ARM64 executable

---

## Troubleshooting

### CGO Cross-Compilation Fails

If building Linux→macOS fails:
```
# runtime/cgo
gcc: error: unrecognized command line option '-arch'
```

Either:
1. Use Option B (macOS runner on indri)
2. Build with `CGO_ENABLED=0` (loses some features)
3. Use a Docker image with macOS cross-compiler (complex)

### Artifact Too Large

Forgejo binary is ~100MB. If upload fails:
- Check Forgejo's artifact size limit in app.ini
- Consider compressing: `gzip -9 forgejo-*`

---

## Next Phase

Once build is working and produces valid binaries, proceed to [Phase 3: Self-Deploy](P3_self_deploy.md).
