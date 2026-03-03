---
title: Build Grafana Container
modified: 2026-02-28
last-reviewed: 2026-02-28
tags:
  - how-to
  - grafana
  - containers
---

# Build Grafana Container

Home-built Grafana container image published to `registry.ops.eblu.me/blumeops/grafana`.

## How It Works

The Dockerfile at `containers/grafana/Dockerfile` downloads the official Grafana OSS tarball for the target architecture (arm64/amd64), installs it into Alpine, and sets up standard paths.

To build and push a new version:

```fish
# Update version in Dockerfile
# ARG CONTAINER_APP_VERSION=12.3.3

mise run container-build-and-release grafana
```

## Gotchas

- **Tarball directory name:** Extracts to `grafana-<version>` (e.g. `grafana-12.3.3`), *not* `grafana-v<version>`.
- **Binary PATH:** The binary lives at `bin/grafana` inside the extracted directory. The Dockerfile sets `ENV PATH="/usr/share/grafana/bin:$PATH"`.
- **UID 472:** Matches the official Grafana image for PVC ownership compatibility.

## Related

- [[grafana]] — Service reference card
- [[upgrade-grafana]] — Migration context
- [[kustomize-grafana-deployment]] — Kustomize manifest structure
- [[build-grafana-sidecar]] — Home-built sidecar container
- [[build-container-image]] — Standard container build workflow
