# Phase 2: Custom Runner Image

**Goal**: Build a custom forgejo-runner image with necessary tools, enabling standard GitHub Actions

**Status**: Complete (2026-01-23)

**Prerequisites**: [Phase 1](P1_enable_actions.md) complete (Actions enabled, runner deployed in host mode)

---

## Problem Statement

The stock `code.forgejo.org/forgejo/runner:3.5.1` image lacks tools needed for standard GitHub Actions:
- **Node.js** - Required by most actions (checkout, setup-*, etc.)
- **Git** - For repository operations (present but minimal)
- **Common build tools** - make, gcc, curl, jq, etc.

In host mode, jobs run directly in the runner container, so these tools must be pre-installed.

### Chicken-and-Egg Problem

We can't use `actions/checkout@v4` to build the custom runner because that action requires Node.js, which we don't have yet. Solution: Bootstrap manually, then automate.

---

## Step 1: Create Dockerfile for Custom Runner

Create `argocd/manifests/forgejo-runner/Dockerfile`:

```dockerfile
FROM code.forgejo.org/forgejo/runner:3.5.1

# The base image is Debian-based
# Install tools needed for GitHub Actions and builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Required for actions/checkout and other Node-based actions
    nodejs \
    npm \
    # Build essentials
    git \
    curl \
    wget \
    jq \
    make \
    gcc \
    g++ \
    # For container builds (if we add Docker-in-Docker later)
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js is available
RUN node --version && npm --version
```

---

## Step 2: Bootstrap - Build Image Manually

Since we can't use CI yet, build the image manually on gilbert and push to zot.

### 2.1 Build with Podman

```bash
cd ~/code/personal/blumeops/argocd/manifests/forgejo-runner

# Build for linux/arm64 (minikube on M1 Mac)
podman build --platform linux/arm64 -t registry.tail8d86e.ts.net/blumeops/forgejo-runner:latest .

# Push to zot (no auth required)
podman push registry.tail8d86e.ts.net/blumeops/forgejo-runner:latest
```

### 2.2 Verify Image in Registry

```bash
curl -s https://registry.tail8d86e.ts.net/v2/blumeops/forgejo-runner/tags/list | jq .
```

---

## Step 3: Update Runner Deployment

### 3.1 Update deployment.yaml

Change the image from stock to custom:

```yaml
# Before
image: code.forgejo.org/forgejo/runner:3.5.1

# After
image: registry.tail8d86e.ts.net/blumeops/forgejo-runner:latest
```

### 3.2 Update kustomization.yaml

Add Dockerfile to resources (for reference, not deployed):

```yaml
# Note: Dockerfile is for building, not k8s deployment
# It lives here for co-location with the runner manifests
```

### 3.3 Sync Deployment

```bash
argocd app sync forgejo-runner

# Verify new image is running
kubectl --context=minikube-indri -n forgejo-runner get pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

---

## Step 4: Test with Real GitHub Action

Now that we have Node.js, test with `actions/checkout@v4`.

### 4.1 Update Test Workflow

Update `.forgejo/workflows/test.yml`:

```yaml
name: Test CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Verify tools
        run: |
          echo "Node.js: $(node --version)"
          echo "npm: $(npm --version)"
          echo "Git: $(git --version)"
          echo "Make: $(make --version | head -1)"

      - name: Show repo info
        run: |
          echo "Repository: ${{ github.repository }}"
          echo "Branch: ${{ github.ref_name }}"
          ls -la
```

### 4.2 Push and Verify

```bash
git add .forgejo/workflows/test.yml
git commit -m "Test checkout action with custom runner"
git push
```

Check https://forge.tail8d86e.ts.net/eblume/blumeops/actions - should see successful run with `actions/checkout@v4`.

---

## Step 5: Create Auto-Build Workflow for Runner

Now that Actions work properly, create a workflow to rebuild the runner image automatically.

### 5.1 Create Build Workflow

Create `.forgejo/workflows/build-runner.yml`:

```yaml
name: Build Runner Image

on:
  push:
    paths:
      - 'argocd/manifests/forgejo-runner/Dockerfile'
      - '.forgejo/workflows/build-runner.yml'
  workflow_dispatch:

env:
  REGISTRY: registry.tail8d86e.ts.net
  IMAGE_NAME: blumeops/forgejo-runner

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build image
        run: |
          cd argocd/manifests/forgejo-runner
          # Use docker build (available in runner container)
          # Note: This builds for the runner's native arch
          docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} .
          docker tag ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
                     ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

      - name: Push to registry
        run: |
          # Zot has no auth, just push
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

      - name: Verify push
        run: |
          curl -sf "https://${{ env.REGISTRY }}/v2/${{ env.IMAGE_NAME }}/tags/list" | jq .
          echo "Image pushed: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}"
```

### 5.2 Note on Docker-in-Docker

The runner runs in host mode, so we need Docker CLI available. Options:

1. **Add Docker CLI to the custom image** (see Dockerfile update below)
2. **Mount Docker socket from minikube** (requires deployment change)
3. **Use Podman instead** (rootless, no socket needed)

For now, we'll add Docker CLI to the image and mount the socket.

### 5.3 Update Dockerfile for Docker Builds

```dockerfile
FROM code.forgejo.org/forgejo/runner:3.5.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    git \
    curl \
    wget \
    jq \
    make \
    gcc \
    g++ \
    ca-certificates \
    # Docker CLI for building container images
    docker.io \
    && rm -rf /var/lib/apt/lists/*

RUN node --version && npm --version && docker --version
```

### 5.4 Update Deployment for Docker Socket

Add Docker socket mount to `deployment.yaml`:

```yaml
volumeMounts:
  - name: runner-data
    mountPath: /data
  - name: runner-config
    mountPath: /config
  - name: docker-sock
    mountPath: /var/run/docker.sock
volumes:
  - name: runner-data
    emptyDir: {}
  - name: runner-config
    configMap:
      name: forgejo-runner-config
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
      type: Socket
```

---

## Step 6: Verification

### 6.1 Manual Image Build Works

```bash
# On gilbert
podman build --platform linux/arm64 -t registry.tail8d86e.ts.net/blumeops/forgejo-runner:test .
podman push registry.tail8d86e.ts.net/blumeops/forgejo-runner:test
```

### 6.2 Runner Uses Custom Image

```bash
kubectl --context=minikube-indri -n forgejo-runner get pods -o jsonpath='{.items[*].spec.containers[*].image}'
# Should show: registry.tail8d86e.ts.net/blumeops/forgejo-runner:latest
```

### 6.3 GitHub Actions Work

- `actions/checkout@v4` succeeds
- Test workflow shows Node.js, npm, git versions

### 6.4 Auto-Build Workflow Works

Push a change to the Dockerfile and verify:
1. Workflow triggers
2. Image builds successfully
3. Image pushed to zot

---

## Verification Checklist

- [x] Dockerfile created for custom runner (Alpine-based with apk)
- [x] Image built manually on gilbert (podman build)
- [x] Image pushed to zot registry
- [x] Runner deployment updated to use custom image
- [x] Runner pod running with new image
- [x] `actions/checkout@v4` works in test workflow
- [ ] Auto-build workflow created (deferred - needs Docker socket)
- [ ] Docker socket mounted (for container builds)
- [ ] Auto-build workflow successfully rebuilds runner

---

## Troubleshooting

### Image Pull Fails in Minikube

Minikube needs to be able to pull from zot. Check registry mirror config:
```bash
ssh indri 'minikube ssh -- cat /etc/containerd/certs.d/registry.tail8d86e.ts.net/hosts.toml'
```

### Docker Build Fails in Workflow

If Docker socket mount doesn't work:
1. Check socket exists in minikube: `minikube ssh -- ls -la /var/run/docker.sock`
2. Check permissions: runner may need to be in docker group
3. Alternative: Use `podman` (rootless) instead of Docker

### Node.js Actions Still Fail

Ensure the runner pod restarted after image update:
```bash
kubectl --context=minikube-indri -n forgejo-runner rollout restart deployment/forgejo-runner
kubectl --context=minikube-indri -n forgejo-runner logs -f deployment/forgejo-runner
```

---

## Next Phase

Once the custom runner is working with auto-build, proceed to [Phase 3: Mirror Forgejo & Build](P3_mirror_and_build.md) to set up Forgejo source builds.
