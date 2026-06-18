---
title: Pin Container Versions
modified: 2026-06-17
tags:
  - how-to
  - containers
  - ci
  - zot
---

# Pin Container Versions

Ensure every container has an explicit, parseable version declaration so that [[add-container-version-sync-check]] has something to validate against.

> **Superseded by [[retire-minikube]] (2026-06):** all containers are now nix-only.
> The `ARG CONTAINER_APP_VERSION` / `container.py` `VERSION` conventions below
> were retired with the Dockerfile/Dagger build paths; versions now live in
> `version = "..."` in each `default.nix`. This card is the historical record.

## Context

Discovered during analysis of [[adopt-commit-based-container-tags]]: containers needed a uniform, parseable version declaration for the sync check. Most containers already had version ARGs (miniflux, navidrome, ntfy, etc.), but with inconsistent naming (`NAVIDROME_VERSION`, `MINIFLUX_VERSION`, etc.), and several containers (devpi, cv, quartz, nettest) had none.

## What Was Done

Every container Dockerfile declares `ARG CONTAINER_APP_VERSION=X.Y.Z` as its first ARG, providing a uniform parsing target. Containers that use the version in build commands chain it to a semantic ARG:

```dockerfile
ARG CONTAINER_APP_VERSION=v0.60.3
ARG NAVIDROME_VERSION=${CONTAINER_APP_VERSION}
```

> **Note:** Containers migrated to native Dagger builds use `VERSION = "X.Y.Z"` in `container.py` instead. See `containers/navidrome/container.py` for the pattern. New containers should use `container.py` rather than Dockerfiles.

Specific changes:
- **devpi**: Pinned devpi-server==6.19.1 and devpi-web==5.0.1
- **cv**: `CONTAINER_APP_VERSION=1.0.3` (matches latest Forgejo package release)
- **quartz**: `CONTAINER_APP_VERSION=1.28.2` (pinned nginx:1.28.2-alpine base)
- **All others**: Existing versions carried forward with new uniform ARG pattern

## Key Files

| File | Change |
|------|--------|
| `containers/*/Dockerfile` | Add `ARG CONTAINER_APP_VERSION` to all 13 containers |
| `service-versions.yaml` | Populate `current-version` for devpi, cv, docs |

## Verification

- [x] Every container Dockerfile has `ARG CONTAINER_APP_VERSION=X.Y.Z`
- [x] ARG chaining tested with Docker build (nginx:1.28.2-alpine)
- [x] devpi container pins pip package versions
- [x] cv version matches Forgejo package release (1.0.3)
- [x] quartz pins nginx base image to stable (1.28.2)

## Related

- [[add-container-version-sync-check]] — Parent: needs parseable versions for sync check
- [[adopt-commit-based-container-tags]] — Grandparent goal
