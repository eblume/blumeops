---
title: Build Grafana Sidecar
modified: 2026-03-03
last-reviewed: 2026-03-03
tags:
  - how-to
  - grafana
  - containers
---

# Build Grafana Sidecar

Home-built k8s-sidecar container image published to `registry.ops.eblu.me/blumeops/grafana-sidecar`.

## How It Works

The Dockerfile at `containers/grafana-sidecar/Dockerfile` clones the [kiwigrid/k8s-sidecar](https://github.com/kiwigrid/k8s-sidecar) source from the forge mirror, installs Python dependencies into a venv, and copies the application into a minimal Alpine runtime image.

To build and push a new version:

```fish
# Update version in Dockerfile
# ARG CONTAINER_APP_VERSION=1.28.0

mise run container-build-and-release grafana-sidecar
```

## Gotchas

- **Pinned to v1.28.0:** v2.x has a 135% memory regression ([#462](https://github.com/kiwigrid/k8s-sidecar/issues/462)) and `readOnlyRootFilesystem` crashloop ([#3936](https://github.com/grafana/helm-charts/issues/3936)). Upgrade separately after upstream fixes land.
- **UID 65534:** Matches upstream's `nobody` user convention for non-root execution.
- **Forge mirror name:** `mirrors/kiwigrid-grafana-sidecar` (not `k8s-sidecar`).

## Related

- [[grafana]] — Service reference card
- [[build-grafana-container]] — Home-built Grafana container
- [[kustomize-grafana-deployment]] — Kustomize manifest structure
- [[build-container-image]] — Standard container build workflow
