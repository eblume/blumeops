---
title: Fix ntfy Nix Version
modified: 2026-02-20
tags:
  - how-to
  - containers
  - nix
  - zot
---

# Fix ntfy Nix Version

Override the nixpkgs ntfy-sh derivation to build v2.17.0 from the forge mirror, aligning the nix-built container with the Dockerfile version.

## Context

Discovered during [[add-container-version-sync-check]]: the ntfy container has both a Dockerfile and a `default.nix`. The Dockerfile builds v2.17.0 from `forge.ops.eblu.me/eblume/ntfy.git`, but the nix derivation uses `pkgs.ntfy-sh` from nixpkgs which is pinned at 2.15.0. The version sync check currently excludes ntfy from nix version validation as a workaround.

## What Was Done

Replaced the nixpkgs `pkgs.ntfy-sh` reference in `containers/ntfy/default.nix` with a custom derivation that builds v2.17.0 from the forge mirror using `fetchgit`, `buildNpmPackage` (web UI), and `buildGoModule` (server). Docs are skipped (placeholder for `go:embed`, matching the Dockerfile approach).

The `container-version-check` script was updated to extract versions from local nix files via regex (`version = "X.Y.Z"`) before falling back to the Dagger `nix-version` function for unmodified nixpkgs packages. This avoids the issue where `nix eval nixpkgs#ntfy-sh.version` returns the upstream 2.15.0 instead of our overridden 2.17.0.

## Key Files

| File | Change |
|------|--------|
| `containers/ntfy/default.nix` | Custom derivation building v2.17.0 from forge |
| `mise-tasks/container-version-check` | Regex-based local nix version extraction |

## Verification

- [x] `dagger call build-nix --src=. --container-name=ntfy` produces a working image
- [x] Version extractable from local `default.nix` via regex (2.17.0)
- [x] `mise run container-version-check --all-files` passes with ntfy included

## Related

- [[add-container-version-sync-check]] — Parent: needs ntfy in NIX_PACKAGE_MAP
- [[harden-zot-registry]] — Root goal
