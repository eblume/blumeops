---
title: Dagger
modified: 2026-04-11
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
| **Engine Version** | v0.20.1 |
| **SDK** | Python |
| **Source** | `src/blumeops/main.py` |
| **Config** | `dagger.json` (source: `.`) |

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `build` | `(src, container_name) → Container` | Build a container — uses native pipeline (`container.py`) if available, falls back to `docker_build()` for Dockerfile containers |
| `container_version` | `(container_name) → str` | Return the `VERSION` from a container's `container.py` (empty string if no `container.py`) |
| `publish` | `(src, container_name, version, registry?) → str` | Build and push to registry (default: `registry.ops.eblu.me`) |
| `build_nix` | `(src, container_name) → File` | Build a nix container from `containers/<name>/default.nix`, return docker-archive tarball |
| `nix_version` | `(package) → str` | Extract the version of a nixpkgs package |
| `build_docs` | `(src, version) → File` | Build Quartz docs site, return docs tarball |
| `flake_lock` | `(src, flake_path?) → File` | Resolve flake inputs, return updated `flake.lock` |
| `flake_update` | `(src, flake_path?) → File` | Update all flake inputs to latest, return `flake.lock` |

## Container Build Types

Containers can be built in three ways:

| Build file | How it works | Error visibility |
|------------|-------------|-----------------|
| `container.py` | Native Dagger pipeline (preferred) | Full per-step output |
| `Dockerfile` | `docker_build()` fallback (legacy) | Opaque — errors swallowed |
| `default.nix` | `nix-build` on ringtail runner | Full nix output |

New containers for indri (k8s runner) should use `container.py`. Ringtail containers should continue using `default.nix`. Existing Dockerfile containers are migrated incrementally during [[review-services|service reviews]]. See `containers/navidrome/container.py` for the reference pattern.

## CLI Examples

```bash
# Build a container
dagger call build --src=. --container-name=devpi

# Drop into container shell for inspection
dagger call build --src=. --container-name=devpi terminal

# Debug a failure interactively
dagger call --interactive build --src=. --container-name=devpi

# Publish a container to zot
dagger call publish --src=. --container-name=devpi --version=v1.1.0

# Build a nix container (no local nix required)
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

Dagger has a first-class `Secret` type — values are never logged or cached. Pass secrets from environment variables using the `env:VAR` syntax:

```bash
dagger call release-docs \
  --src=. --version=v1.6.0 \
  --forgejo-token=env:FORGEJO_TOKEN \
  --argocd-token=env:ARGOCD_TOKEN
```

In [[forgejo]] Actions, secrets are injected as env vars. Locally, mise tasks call `op read` to populate them.

## Caveats

- **Pre-1.0 API** — Current version is v0.20.x. Pin the CLI version and test upgrades on a branch before adopting. See [[upgrade-dagger]] for the upgrade procedure.
- **Privileged container** — The Dagger engine requires privileged container access. The Forgejo runner's DinD sidecar provides this.

## Related

- [[forgejo]] — CI/CD trigger layer
- [[zot]] — Container registry (publish target)
- [[docs]] — Documentation site (build target)
- [[manage-lockfile]] — Ringtail flake lockfile management
