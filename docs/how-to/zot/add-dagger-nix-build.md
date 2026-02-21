---
title: Add Dagger Nix Build Function
modified: 2026-02-20
status:
tags:
  - how-to
  - containers
  - ci
  - dagger
  - zot
---

# Add Dagger Nix Build Function

Add Dagger functions for building nix container images and extracting version info from nix derivations. This enables local nix container evaluation and provides the version extraction mechanism needed by [[add-container-version-sync-check]].

## Context

Discovered during analysis of [[adopt-commit-based-container-tags]]: nix containers (authentik, ntfy, nettest) derive their bundled app version from the nixpkgs pin, not from an explicit declaration. To validate that a VERSION file matches the actual nix-built version, we need a way to query the version from nix.

Currently, nix containers can only be built on ringtail (the `nix-container-builder` runner). There is no local build path for developers — the only option is to push and wait for CI. Adding a Dagger-based nix build gives both local evaluation and version extraction.

## What to Do

### 1. Add `build_nix` Dagger function

A new function in `.dagger/src/blumeops_ci/main.py` that builds a nix container inside a `nixos/nix` container:

```python
@function
async def build_nix(
    self, src: dagger.Directory, container_name: str
) -> dagger.File:
    """Build a nix container from containers/<name>/default.nix. Returns the image tarball."""
    # Uses NIX_IMAGE (nixos/nix:2.33.3) — already defined in the module
    # Runs nix-build inside the container
    # Returns the docker-archive tarball
```

This mirrors the existing `build` function (Dockerfile) but for nix. The result is a docker-archive tarball that can be loaded with `docker load` or pushed with `skopeo`.

### 2. Add `nix_version` Dagger function

A function that extracts the version of a specific nix package from the nixpkgs pin:

```python
@function
async def nix_version(
    self, src: dagger.Directory, package: str
) -> str:
    """Extract the version of a nixpkgs package. Returns version string."""
    # nix eval --raw nixpkgs#<package>.version
```

This lets the version sync check run `dagger call nix-version --src=. --package=authentik` to get the actual version that would be built.

### 3. Add `publish_nix` Dagger function (optional)

If useful, a combined build-and-push that mirrors `publish` but for nix images:

```python
@function
async def publish_nix(
    self, src: dagger.Directory, container_name: str, version: str,
    registry: str = "registry.ops.eblu.me",
) -> str:
    """Build nix container and push to registry via skopeo."""
```

This would give a `dagger call publish-nix` path parallel to the existing `dagger call publish`.

## Nix in Dagger

The `flake_lock` function already demonstrates running nix inside Dagger using `nixos/nix:2.33.3`. The nix build function follows the same pattern but needs:

- `NIX_PATH` set to resolved nixpkgs (same as the CI workflow does)
- `--extra-experimental-features "nix-command flakes"` for `nix eval`
- The full repo source mounted (nix files may reference other files like `test-connectivity.sh`)

## Key Files

| File | Change |
|------|--------|
| `.dagger/src/blumeops_ci/main.py` | Add `build_nix`, `nix_version`, optionally `publish_nix` |

## Verification

- [ ] `dagger call build-nix --src=. --container-name=nettest` produces a valid docker-archive tarball
- [ ] `dagger call nix-version --src=. --package=ntfy-sh` returns the correct version string
- [ ] `dagger call nix-version --src=. --package=authentik` returns the Authentik version
- [ ] Tarball from `build-nix` can be loaded with `docker load` and run locally

## Related

- [[add-container-version-sync-check]] — Parent: needs nix version extraction for sync check
- [[adopt-commit-based-container-tags]] — Grandparent goal
- [[dagger]] — Dagger reference
