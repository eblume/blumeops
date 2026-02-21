---
title: Install Dagger on Nix Runner
modified: 2026-02-20
tags:
  - how-to
  - ci
  - zot
---

# Install Dagger on Nix Runner

Install the Dagger CLI on the ringtail nix-container-builder runner so that the nix container build workflow can use `dagger call nix-version` to extract package versions from nixpkgs.

## Context

The `build-container-nix.yaml` workflow extracts container versions in this order:

1. `version = "..."` from `default.nix` (e.g. ntfy)
2. `ARG CONTAINER_APP_VERSION=` from Dockerfile (e.g. nettest)
3. `dagger call nix-version --package=<name>` for nixpkgs packages (e.g. authentik)

Step 3 fails on the ringtail nix runner because dagger is not installed. The runner currently only has nix, skopeo, and jq.

## What to Do

1. Add `dagger` to the ringtail nix runner environment in `nixos/ringtail/configuration.nix` (or equivalent)
2. Verify `dagger` is available in the runner's PATH
3. Re-run `mise run container-build-and-release authentik` to confirm the nix build succeeds

## Verification

- [ ] `ssh ringtail 'which dagger'` returns a path
- [ ] Authentik nix build workflow completes successfully
- [ ] `dagger call nix-version --package=authentik` works on the runner

## Related

- [[adopt-commit-based-container-tags]] — Parent card
- [[harden-zot-registry]] — Root goal
