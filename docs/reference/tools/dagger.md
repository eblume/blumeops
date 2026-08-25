---
title: Dagger
modified: 2026-08-25
last-reviewed: 2026-08-25
tags:
  - reference
  - ci-cd
  - dagger
---

# Dagger

Build engine for BlumeOps CI/CD pipelines. Replaces shell-based build scripts with Python functions that run identically locally and in CI.

## Quick Reference

| Property | Value |
|----------|-------|
| **Module** | `blumeops` |
| **Engine Version** | v0.21.8 |
| **SDK** | Python |
| **Source** | `src/blumeops/main.py` |
| **Config** | `dagger.json` (engineVersion v0.21.8, Python SDK) |

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `build_nix` | `(src, container_name) → File` | Build a nix container from `containers/<name>/default.nix`, return docker-archive tarball |
| `nix_version` | `(package) → str` | Extract the version of a nixpkgs package |
| `build_docs` | `(src, version) → File` | Build Quartz docs site, return docs tarball |
| `flake_lock` | `(src, flake_path?) → File` | Resolve flake inputs, return updated `flake.lock` |
| `flake_update` | `(src, flake_path?, skip_inputs?) → File` | Update rolling flake inputs to latest, return `flake.lock` |
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

# Check a nixpkgs package version
dagger call nix-version --package=authentik

# Build docs tarball locally
dagger call build-docs --src=. --version=dev export --path=./docs-dev.tar.gz

# Debug a docs build failure
dagger call --interactive build-docs --src=. --version=dev

# Update all ringtail flake inputs
dagger call flake-update --src=. --flake-path=nixos/ringtail \
    export --path=nixos/ringtail/flake.lock
```

## Secrets

Dagger has a first-class `Secret` type — values are never logged or cached. When a function accepts a secret, pass a value from an environment variable using the `env:VAR` syntax (e.g. `--token=env:FORGEJO_TOKEN`).

None of the current functions take a secret. For example, `build-docs` only runs the Quartz build; the Forgejo token that publishes the release is passed to the runner job as an env var in [[forgejo]] Actions (`.forgejo/workflows/build-blumeops.yaml`), not through Dagger. Locally, mise tasks call `op read` to populate secrets they need.

## Caveats

- **Pre-1.0 API** — Current version is v0.21.x. Pin the CLI version and test upgrades on a branch before adopting. See [[upgrade-dagger]] for the upgrade procedure.
- **Privileged container** — The Dagger engine requires privileged container access. The Forgejo runner's DinD sidecar provides this.

## Related

- [[forgejo]] — CI/CD trigger layer
- [[zot]] — Container registry (publish target)
- [[docs]] — Documentation site (build target)
- [[manage-lockfile]] — Ringtail flake lockfile management
