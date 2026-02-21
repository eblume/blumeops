---
title: Dagger
modified: 2026-02-20
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
| **Module** | `blumeops-ci` |
| **Engine Version** | v0.19.11 |
| **SDK** | Python |
| **Source** | `.dagger/src/blumeops_ci/main.py` |
| **Config** | `dagger.json` |

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `build` | `(src, container_name) → Container` | Build a container from `containers/<name>/Dockerfile` |
| `publish` | `(src, container_name, version, registry?) → str` | Build and push to registry (default: `registry.ops.eblu.me`) |
| `build_nix` | `(src, container_name) → File` | Build a nix container from `containers/<name>/default.nix`, return docker-archive tarball |
| `nix_version` | `(package) → str` | Extract the version of a nixpkgs package |
| `build_docs` | `(src, version) → File` | Build Quartz docs site, return docs tarball |
| `flake_lock` | `(src, flake_path?) → File` | Resolve flake inputs, return updated `flake.lock` |

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
dagger call build-nix --src=. --container-name=nettest export --path=./nettest.tar.gz

# Check a nixpkgs package version
dagger call nix-version --package=authentik

# Build docs tarball locally
dagger call build-docs --src=. --version=dev export --path=./docs-dev.tar.gz

# Debug a docs build failure
dagger call --interactive build-docs --src=. --version=dev
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

- **Pre-1.0 API** — Current version is v0.19.x. Pin the CLI version and test upgrades on a branch before adopting.
- **Privileged container** — The Dagger engine requires privileged container access. The Forgejo runner's DinD sidecar provides this.

## Related

- [[forgejo]] — CI/CD trigger layer
- [[zot]] — Container registry (publish target)
- [[docs]] — Documentation site (build target)
- [[adopt-dagger-ci]] — Adoption plan (phases 1–3 complete)
