# Phase 4: Container Image Builds

**Goal**: Set up CI workflows to build custom container images and push to zot registry

**Status**: Planning

**Prerequisites**: [Phase 3](P3_self_deploy.md) complete (Forgejo self-deploying, Actions working)

---

## Overview

With Forgejo Actions operational, we can now build container images for:
- Custom devpi with pre-installed plugins
- Any other custom images needed for k8s services
- Release artifacts for Python packages

---

## Use Case 1: devpi Custom Image

### Current State

devpi runs from `registry.tail8d86e.ts.net/blumeops/devpi:latest`, built manually:
- Base image: python
- Adds: devpi-server, devpi-web
- Startup script for auto-initialization

### Goal

Automate builds triggered by:
- Push to devpi repo on forge
- Manual workflow dispatch
- Optionally: upstream devpi release (via schedule check)

---

## Step 1: Create Workflow for devpi

### 1.1 Ensure devpi Repo Has Dockerfile

The Dockerfile already exists at `argocd/manifests/devpi/Dockerfile`. We'll create a workflow in the blumeops repo that builds it.

### 1.2 Create Build Workflow

Create `.forgejo/workflows/build-devpi.yml` in blumeops repo:

```yaml
name: Build devpi Image

on:
  push:
    paths:
      - 'argocd/manifests/devpi/Dockerfile'
      - 'argocd/manifests/devpi/start.sh'
      - '.forgejo/workflows/build-devpi.yml'
  workflow_dispatch:
    inputs:
      tag:
        description: 'Image tag (default: latest)'
        required: false
        default: 'latest'

env:
  REGISTRY: registry.tail8d86e.ts.net
  IMAGE_NAME: blumeops/devpi

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Determine tag
        id: tag
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            TAG="${{ github.event.inputs.tag }}"
          else
            TAG="latest"
          fi
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"

      - name: Build image
        uses: docker/build-push-action@v5
        with:
          context: argocd/manifests/devpi
          file: argocd/manifests/devpi/Dockerfile
          platforms: linux/arm64
          load: true
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}

      - name: Push to registry
        run: |
          # Zot has no auth, just push
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}

      - name: Verify push
        run: |
          # Check image exists in registry
          curl -sf "https://${{ env.REGISTRY }}/v2/${{ env.IMAGE_NAME }}/tags/list" | jq .
```

### 1.3 Runner Needs Registry Access

The runner needs to reach `registry.tail8d86e.ts.net`. This should work via Tailscale egress (same as Forgejo access).

If not, add egress for registry in `argocd/manifests/tailscale-operator/`:
```yaml
apiVersion: tailscale.com/v1alpha1
kind: Connector
metadata:
  name: egress-registry
  namespace: tailscale-operator
spec:
  hostname: egress-registry
  subnetRouter:
    advertiseRoutes:
      - registry.tail8d86e.ts.net/32
```

---

## Step 2: Test Build Workflow

### 2.1 Push and Trigger

```bash
# Make a small change to trigger
echo "# Build $(date)" >> argocd/manifests/devpi/Dockerfile
git add argocd/manifests/devpi/Dockerfile
git commit -m "Trigger devpi image rebuild"
git push
```

### 2.2 Monitor Build

1. Go to https://forge.tail8d86e.ts.net/eblume/blumeops/actions
2. Watch "Build devpi Image" workflow
3. Verify success

### 2.3 Verify Image in Registry

```bash
curl -s https://registry.tail8d86e.ts.net/v2/blumeops/devpi/tags/list | jq .
```

### 2.4 Restart devpi to Use New Image

```bash
kubectl --context=minikube-indri -n devpi rollout restart statefulset/devpi
```

---

## Step 3: Reusable Container Build Workflow

### 3.1 Create Reusable Workflow

Create `.forgejo/workflows/build-container.yml`:

```yaml
name: Build Container Image

on:
  workflow_call:
    inputs:
      context:
        description: 'Build context path'
        required: true
        type: string
      dockerfile:
        description: 'Dockerfile path (relative to context)'
        required: false
        type: string
        default: 'Dockerfile'
      image_name:
        description: 'Image name (without registry)'
        required: true
        type: string
      tag:
        description: 'Image tag'
        required: false
        type: string
        default: 'latest'
      platforms:
        description: 'Target platforms'
        required: false
        type: string
        default: 'linux/arm64'

env:
  REGISTRY: registry.tail8d86e.ts.net

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ${{ inputs.context }}
          file: ${{ inputs.context }}/${{ inputs.dockerfile }}
          platforms: ${{ inputs.platforms }}
          push: true
          tags: ${{ env.REGISTRY }}/${{ inputs.image_name }}:${{ inputs.tag }}

      - name: Verify push
        run: |
          curl -sf "https://${{ env.REGISTRY }}/v2/${{ inputs.image_name }}/tags/list" | jq .
```

### 3.2 Use in devpi Workflow

Simplify `.forgejo/workflows/build-devpi.yml`:

```yaml
name: Build devpi Image

on:
  push:
    paths:
      - 'argocd/manifests/devpi/**'
  workflow_dispatch:

jobs:
  build:
    uses: ./.forgejo/workflows/build-container.yml
    with:
      context: argocd/manifests/devpi
      image_name: blumeops/devpi
```

---

## Step 4: Python Package Builds (Optional)

### 4.1 Use Case

Build Python packages from forge repos and publish to devpi.

Example: `mcquack` package (LaunchAgent management library)

### 4.2 Create Python Build Workflow

Create `.forgejo/workflows/build-python.yml`:

```yaml
name: Build Python Package

on:
  workflow_call:
    inputs:
      package_path:
        description: 'Path to package (contains pyproject.toml)'
        required: false
        type: string
        default: '.'
      python_version:
        description: 'Python version'
        required: false
        type: string
        default: '3.12'
      publish:
        description: 'Publish to devpi'
        required: false
        type: boolean
        default: false
    secrets:
      DEVPI_PASSWORD:
        required: false

env:
  DEVPI_URL: https://pypi.tail8d86e.ts.net

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ inputs.python_version }}

      - name: Install uv
        run: pip install uv

      - name: Build package
        run: |
          cd ${{ inputs.package_path }}
          uv build

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: ${{ inputs.package_path }}/dist/

      - name: Publish to devpi
        if: inputs.publish
        run: |
          cd ${{ inputs.package_path }}
          uv publish \
            --publish-url ${{ env.DEVPI_URL }}/eblume/dev/ \
            --username eblume \
            --password "${{ secrets.DEVPI_PASSWORD }}"
```

---

## Step 5: Scheduled Builds (Cron)

### 5.1 Weekly Rebuild

Keep images fresh with weekly rebuilds:

```yaml
name: Weekly Image Rebuilds

on:
  schedule:
    # Every Sunday at 3 AM UTC
    - cron: '0 3 * * 0'
  workflow_dispatch:

jobs:
  devpi:
    uses: ./.forgejo/workflows/build-container.yml
    with:
      context: argocd/manifests/devpi
      image_name: blumeops/devpi
```

---

## Future Improvements

### Multi-Arch Builds

For images that need both ARM64 and AMD64:

```yaml
platforms: linux/arm64,linux/amd64
```

Requires QEMU emulation setup in runner (already supported by buildx).

### Build Caching

Use GitHub/Forgejo cache actions:

```yaml
- name: Cache Docker layers
  uses: actions/cache@v4
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ hashFiles('**/Dockerfile') }}
```

### Security Scanning

Add Trivy or similar:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: '${{ env.REGISTRY }}/${{ inputs.image_name }}:${{ inputs.tag }}'
```

---

## Verification Checklist

- [ ] devpi build workflow created
- [ ] devpi image builds successfully
- [ ] Image pushed to zot registry
- [ ] devpi pod uses new image
- [ ] Reusable container workflow created
- [ ] (Optional) Python build workflow created
- [ ] (Optional) Scheduled builds configured

---

## Summary

With this phase complete, we have:
1. **Forgejo Actions** running with k8s runner
2. **Forgejo self-deploys** from CI on tagged releases
3. **Container images** built automatically on push
4. Infrastructure for Python package builds

The CI/CD bootstrap is complete. Future work:
- Add more container builds as needed
- Add Python package publishing for internal tools
- Consider adding a macOS runner on indri for native builds
