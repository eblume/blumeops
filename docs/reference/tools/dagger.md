---
title: Dagger
modified: 2026-09-05
last-reviewed: 2026-09-05
tags:
  - reference
  - ci-cd
  - dagger
---

# Dagger

Build engine for the container builds that still need it. Docs and nix-built
images no longer use it: the docs build is a direct node:22-slim run (the
`docs-build-tarball` task), and container images are built with nix on the
`nix-container-builder` runner.

## Quick Reference

| Property | Value |
|----------|-------|
| **Module** | `blumeops` |
| **Engine Version** | v0.21.9 |
| **SDK** | Python |
| **Source** | `src/blumeops/main.py` |
| **Config** | `dagger.json` (engineVersion v0.21.9, Python SDK) |

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `build_nix` | `(src, container_name) → File` | Build a nix container from `containers/<name>/default.nix`, return docker-archive tarball |
| `export_yolov9` | `(model_size?, input_size?) → File` | Export YOLOv9 weights to ONNX for [[frigate|Frigate]] |

## Container Build Types

All BlumeOps containers are built from `containers/<name>/default.nix` via
`nix-build` on the `nix-container-builder` runner ([[ringtail]]), then pushed
to [[zot]] (amd64, `:vX.Y.Z-<sha>-nix` tags). See [[build-container-image]].

> Until [[retire-minikube]] (2026-06), containers could also be built from a
> `Dockerfile` (`docker_build()`) or a native `container.py` Dagger pipeline,
> routed to an arm64 k8s runner. Both build paths — and the `build`,
> `publish`, and `container_version` Dagger functions that drove them — were
> retired with the minikube cluster.

## CLI Examples

```bash
# Build a nix container locally (no local nix required)
dagger call build-nix --src=. --container-name=ntfy export --path=./ntfy.tar.gz

```

## Caveats

- **Pre-1.0 API** — Current version is v0.21.x. Pin the CLI version and test upgrades on a branch before adopting. See [[upgrade-dagger]] for the upgrade procedure.
- **Engine** — The Dagger engine runs as a container inside indri's Docker Desktop (2cpu/4GiB), driven by the mise-pinned CLI on the host-mode runner.

## Related

- [[forgejo]] — CI/CD trigger layer
- [[zot]] — Container registry (publish target)
- [[docs]] — Documentation site (build target)
- [[manage-lockfile]] — Ringtail flake lockfile management
