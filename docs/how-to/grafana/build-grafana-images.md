---
title: Build Grafana Images
modified: 2026-03-15
last-reviewed: 2026-03-15
tags:
  - how-to
  - grafana
  - containers
---

# Build Grafana Images

Home-built container images for Grafana and its dashboard sidecar, published to `registry.ops.eblu.me/blumeops/`.

## Grafana

**Dockerfile:** `containers/grafana/Dockerfile`
**Image:** `registry.ops.eblu.me/blumeops/grafana`

Downloads the official Grafana OSS tarball for the target architecture (arm64/amd64), installs it into Alpine, and sets up standard paths.

```fish
# Update version in Dockerfile
# ARG CONTAINER_APP_VERSION=12.3.3

mise run container-build-and-release grafana
```

**Gotchas:**

- **Tarball directory name:** Extracts to `grafana-<version>` (e.g. `grafana-12.3.3`), *not* `grafana-v<version>`.
- **Binary PATH:** The binary lives at `bin/grafana` inside the extracted directory. The Dockerfile sets `ENV PATH="/usr/share/grafana/bin:$PATH"`.
- **UID 472:** Matches the official Grafana image for PVC ownership compatibility.

## Grafana Sidecar

**Dockerfile:** `containers/grafana-sidecar/Dockerfile`
**Image:** `registry.ops.eblu.me/blumeops/grafana-sidecar`

Clones the [kiwigrid/k8s-sidecar](https://github.com/kiwigrid/k8s-sidecar) source from the forge mirror, installs Python dependencies into a venv, and copies the application into a minimal Alpine runtime image.

```fish
# Update version in Dockerfile
# ARG CONTAINER_APP_VERSION=1.28.0

mise run container-build-and-release grafana-sidecar
```

**Gotchas:**

- **Pinned to v1.28.0:** v2.x has a 135% memory regression ([#462](https://github.com/kiwigrid/k8s-sidecar/issues/462)) and `readOnlyRootFilesystem` crashloop ([#3936](https://github.com/grafana/helm-charts/issues/3936)). Upgrade separately after upstream fixes land.
- **UID 65534:** Matches upstream's `nobody` user convention for non-root execution.
- **Forge mirror name:** `mirrors/kiwigrid-grafana-sidecar` (not `k8s-sidecar`).

## Related

- [[grafana]] — Service reference card
- [[upgrade-grafana]] — Migration context and future upgrade steps
- [[kustomize-grafana-deployment]] — Kustomize manifest structure
- [[build-container-image]] — Standard container build workflow
