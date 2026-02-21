---
title: Add Container Version Sync Check
modified: 2026-02-20
requires:
  - pin-container-versions
  - add-dagger-nix-build
  - fix-ntfy-nix-version
tags:
  - how-to
  - containers
  - ci
  - zot
---

# Add Container Version Sync Check

Add a pre-commit check that validates version consistency across the three places container versions are declared: Dockerfile ARGs, `service-versions.yaml`, and nix derivations. No VERSION files needed — the existing sources are the source of truth, and the check enforces they agree.

## Context

Discovered during analysis of [[adopt-commit-based-container-tags]]: the new commit-SHA-based image tags need a reliable version source (`vX.Y.Z-<sha>`). Versions are currently scattered across Dockerfile ARGs (varying naming conventions), `service-versions.yaml` entries (many still `null`), and nix derivations (implicit from nixpkgs). A sync check ensures these stay consistent without adding a redundant fourth source.

## What Was Done

### 1. Created `mise run container-version-check` task

A typer-based uv-script that iterates over `containers/*/` and validates five rules per container:

1. Any Dockerfile must declare `ARG CONTAINER_APP_VERSION=<value>`
2. Any `default.nix` must produce a version via `dagger call nix-version`
3. At least one build file must exist (Dockerfile or default.nix)
4. A matching `service-versions.yaml` entry must exist with non-null `current-version`
5. All resolved versions from (1), (2), and (4) must agree (v-prefix stripped for comparison)

Scoping: by default only checks containers changed vs main. `--all-files` checks everything. If `service-versions.yaml` itself changed, all containers are checked.

Blacklisted containers (utility images, not tracked services): `kubectl`, `nettest`.

Container-to-service name mapping: `quartz` → `docs`, `kiwix-serve` → `kiwix`.

### 2. Added pre-commit hook

```yaml
- id: container-version-check
  name: container-version-check
  entry: mise run container-version-check
  language: system
  files: ^(containers/|service-versions\.yaml)
  pass_filenames: false
```

### 3. Populated `service-versions.yaml`

Filled in `current-version` for all hybrid services: navidrome (v0.60.3), miniflux (2.2.17), teslamate (v2.2.0), transmission (4.0.6-r4), kiwix (3.8.1), forgejo-runner (0.19.11). Added authentik (2025.10.1) as a new hybrid entry.

### ntfy nix version skew (resolved)

The check discovered that ntfy's Dockerfile pins v2.17.0 but nixpkgs has ntfy-sh 2.15.0. This was resolved in [[fix-ntfy-nix-version]] by building a custom nix derivation from the forge mirror. The version check now extracts the version from local nix files via regex, falling back to Dagger for unmodified nixpkgs packages.

## Key Files

| File | Change |
|------|--------|
| `mise-tasks/container-version-check` | New: typer CLI sync validation script |
| `.pre-commit-config.yaml` | Add `container-version-check` hook |
| `service-versions.yaml` | Populate `current-version` for all hybrid services + authentik |

## Verification

- [x] `mise run container-version-check --all-files` passes with no errors
- [x] Intentionally changing a Dockerfile ARG without updating `service-versions.yaml` fails the check
- [x] `service-versions.yaml` has `current-version` populated for all hybrid services
- [x] Nix-only container versions (authentik) checked via Dagger
- [x] ntfy nix version resolved via [[fix-ntfy-nix-version]]

## Related

- [[pin-container-versions]] — Prereq: containers need parseable version ARGs first
- [[add-dagger-nix-build]] — Prereq: nix version extraction
- [[fix-ntfy-nix-version]] — Prereq: ntfy nix derivation version skew
- [[adopt-commit-based-container-tags]] — Parent: CI uses the same version extraction at build time
- [[harden-zot-registry]] — Root goal
