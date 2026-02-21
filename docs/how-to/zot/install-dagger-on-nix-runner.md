---
title: Install Dagger on Nix Runner
modified: 2026-02-20
tags:
  - how-to
  - ci
  - zot
---

# Install Dagger on Nix Runner

Use `nix eval` instead of `dagger call nix-version` for version extraction on the ringtail nix-container-builder runner.

## Context

The `build-container-nix.yaml` workflow extracts container versions in this order:

1. `version = "..."` from `default.nix` (e.g. ntfy)
2. `ARG CONTAINER_APP_VERSION=` from Dockerfile (e.g. nettest)
3. Nixpkgs package version for packages without explicit versions (e.g. authentik)

Step 3 originally used `dagger call nix-version`, but dagger can't run on the bare nix runner:

- **Dagger is not in nixpkgs** — removed due to [trademark concerns](https://github.com/NixOS/nixpkgs/issues/260848). Available via `github:dagger/nix` flake.
- **Dagger needs a container runtime** — the CLI is just an API client; the engine runs as a container via Docker/containerd, which the nix runner doesn't have.

The fix was to use `nix eval --raw "nixpkgs#<package>.version"` directly, which is already available on the nix host and more appropriate.

## Related

- [[adopt-commit-based-container-tags]] — Parent card
- [[harden-zot-registry]] — Root goal
