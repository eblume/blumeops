# Phase 3: Mirror Forgejo & Build from Source

**Goal**: Mirror upstream Forgejo to forge and create a workflow that builds it for macOS ARM64

**Status**: Planning

**Prerequisites**: [Phase 2](P2_mirror_and_build.md) complete (custom runner image with Node.js/tools)

---

## Problem Statement

We want to build Forgejo from source to:
1. Have full control over the binary running on indri
2. Enable self-deployment via CI
3. Ensure proper macOS DNS resolution (requires CGO_ENABLED=1)

### The Cross-Compilation Challenge

The runner runs in a Linux container (k8s on indri), but the target is macOS ARM64 (indri itself).

**Options**:

| Option | Pros | Cons |
|--------|------|------|
| A. Cross-compile CGO_ENABLED=0 | Simple, no special toolchain | Breaks Tailscale MagicDNS resolution |
| B. Cross-compile CGO_ENABLED=1 | Proper DNS | Needs OSX cross-compiler (osxcross), complex |
| C. Build on gilbert manually | Works now, simple | Not automated, manual step |
| D. Native macOS runner on indri | Full native build | Runner outside k8s, different architecture |
| E. Hybrid: build on gilbert, deploy via CI | Uses existing tools | Partial automation |

**Recommendation**: Start with Option C/E (manual build on gilbert, CI just deploys), then consider Option D if we want full automation.

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

# Build backend (with CGO for proper DNS on macOS)
CGO_ENABLED=1 TAGS="bindata sqlite sqlite_unlock_notify" make backend

# Or all-in-one
CGO_ENABLED=1 TAGS="bindata sqlite sqlite_unlock_notify" make build
```

### 2.3 Output

Binary at `gitea` (yes, the binary is still named `gitea` for compatibility).

---

## Step 3: Build on Gilbert (Manual Bootstrap)

For the initial bootstrap, build on gilbert (macOS ARM64 native).

### 3.1 Setup Build Environment

```bash
cd ~/code/3rd/forgejo
mise use go@1.23 node@20

# Verify tools
go version
node --version
make --version
```

### 3.2 Build

```bash
# Clean build
make clean

# Build frontend
make deps-frontend
make frontend

# Build backend with CGO (important for macOS DNS!)
CGO_ENABLED=1 TAGS="bindata sqlite sqlite_unlock_notify" make backend

# Verify binary
./gitea --version
file gitea  # Should show: Mach-O 64-bit executable arm64
```

### 3.3 Deploy to Indri

```bash
# Copy binary
scp gitea indri:~/.local/bin/forgejo-new

# Verify on indri
ssh indri '~/.local/bin/forgejo-new --version'
```

---

## Step 4: Create Deploy Workflow (Option E)

Since cross-compilation is complex, use a hybrid approach:
1. Build on gilbert (manual trigger or pre-built)
2. CI workflow fetches and deploys

### 4.1 SSH Deploy Key for Runner

The runner needs SSH access to indri to deploy the binary.

**Generate key on gilbert**:
```bash
ssh-keygen -t ed25519 -C "forgejo-runner-deploy" -f ~/.ssh/forgejo-runner-deploy -N ""
```

**Add public key to indri's authorized_keys**:
```bash
cat ~/.ssh/forgejo-runner-deploy.pub | ssh indri 'cat >> ~/.ssh/authorized_keys'
```

**Store private key in 1Password** (blumeops vault) as "Forgejo Runner Deploy Key"

### 4.2 Create k8s Secret

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
    # Get with: ssh-keyscan indri.tail8d86e.ts.net 2>/dev/null | grep ed25519
    indri.tail8d86e.ts.net ssh-ed25519 AAAAC3...
```

### 4.3 Update Deployment for SSH

Add SSH secret mount to `deployment.yaml`:

```yaml
volumeMounts:
  - name: ssh-key
    mountPath: /root/.ssh
    readOnly: true
volumes:
  - name: ssh-key
    secret:
      secretName: forgejo-runner-ssh
      defaultMode: 0600
```

### 4.4 Create Deploy-Only Workflow

Create `.forgejo/workflows/deploy-forgejo.yml` in blumeops:

```yaml
name: Deploy Forgejo

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy (tag or commit)'
        required: true
        default: 'v10.0.0'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Deploy to indri
        env:
          VERSION: ${{ github.event.inputs.version }}
        run: |
          # SSH config
          mkdir -p ~/.ssh
          cp /root/.ssh/id_ed25519 ~/.ssh/
          cp /root/.ssh/known_hosts ~/.ssh/
          chmod 600 ~/.ssh/id_ed25519

          # Deploy script
          ssh erichblume@indri.tail8d86e.ts.net << 'EOF'
            set -e
            cd ~/.local/bin

            # Verify the new binary exists and runs
            if [ ! -f forgejo-new ]; then
              echo "ERROR: forgejo-new not found. Build on gilbert first:"
              echo "  cd ~/code/3rd/forgejo && git checkout $VERSION"
              echo "  CGO_ENABLED=1 TAGS='bindata sqlite sqlite_unlock_notify' make build"
              echo "  scp gitea indri:~/.local/bin/forgejo-new"
              exit 1
            fi

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

---

## Future: Full CI Build (Option D)

If we want full automation, consider running a native macOS runner on indri:

### Native Runner on Indri

```bash
# Install forgejo-runner on indri via mise
ssh indri 'mise use forgejo-runner'

# Register as a macOS runner
ssh indri 'forgejo-runner register \
  --instance https://forge.tail8d86e.ts.net \
  --token "$TOKEN" \
  --name "indri-native" \
  --labels "macos-arm64:host" \
  --no-interactive'

# Create LaunchAgent for runner
# (similar to other mcquack services)
```

Then workflow uses:
```yaml
runs-on: macos-arm64
```

This enables full native builds in CI. Document in a future phase if needed.

---

## Verification Checklist

- [ ] Forgejo mirrored to forge
- [ ] Mirror cloned to ~/code/3rd/forgejo
- [ ] Build succeeds on gilbert
- [ ] Binary is valid macOS ARM64 executable
- [ ] Binary deployed to indri ~/.local/bin/
- [ ] SSH deploy key created and stored in 1Password
- [ ] Deploy key added to indri authorized_keys
- [ ] (Optional) k8s SSH secret created
- [ ] (Optional) Deploy workflow created

---

## Troubleshooting

### Build Fails: Node.js Version

```
error: engine "node" is incompatible
```

Update Node.js: `mise use node@20`

### Build Fails: Go Version

```
go: go.mod requires go >= 1.23
```

Update Go: `mise use go@1.23`

### Binary Crashes on indri

Check if CGO was enabled:
```bash
# If built without CGO, DNS resolution may fail
./forgejo --version  # Should work
./forgejo web        # May fail to resolve Tailscale hostnames
```

Rebuild with `CGO_ENABLED=1`.

### SSH Deploy Fails

Check runner has SSH access:
```bash
# Test from inside runner pod
kubectl --context=minikube-indri -n forgejo-runner exec deployment/forgejo-runner -- \
  ssh -i /root/.ssh/id_ed25519 erichblume@indri.tail8d86e.ts.net 'echo ok'
```

---

## Next Phase

Once Forgejo is building and deploying successfully, proceed to [Phase 4: Self-Deploy](P4_self_deploy.md) for the full mcquack transition.
