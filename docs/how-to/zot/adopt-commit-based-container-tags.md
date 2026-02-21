---
title: Adopt Commit-Based Container Tags
modified: 2026-02-20
requires:
  - add-container-version-sync-check
tags:
  - how-to
  - containers
  - ci
  - zot
---

# Adopt Commit-Based Container Tags

Replace the current git-tag-triggered container build system with path-based triggers and commit-SHA-based image tags, so that container versions reflect the actual bundled app version and are traceable to exact source commits.

## Context

Currently, container builds trigger on git tags matching `<container>-vX.Y.Z`. The version is chosen arbitrarily at release time and is not connected to the upstream app version bundled in the image. This creates several problems:

- **Version opacity** — `v1.0.0` of a container tells you nothing about which upstream version it bundles
- **Manual release step** — `mise run container-tag-and-release` must be run by hand for every build
- **No automatic rebuilds** — changes to a container's build files don't trigger builds unless someone creates a tag
- **Mutable risk** — version tags can be re-pushed (addressed separately by [[enforce-tag-immutability]], but commit SHAs are inherently unique)

## New Scheme

### Triggers

1. **Merged changes to main** — any push to `main` that modifies files under `containers/<name>/` triggers builds for that container
2. **Manual workflow dispatch** — for ad-hoc builds. Accepts two inputs:
   - `container` (required) — which container to build
   - `ref` (optional, string) — the source commit SHA to build, defaulting to `GITHUB_SHA`

Both the Dockerfile and Nix workflows fire for each trigger, each bailing out if the container lacks the relevant build file (same as today).

### Version Source

Each container's version is extracted at build time from existing declarations — no separate VERSION file:

- **Dockerfile builds**: parsed from `ARG CONTAINER_APP_VERSION=<value>` in the Dockerfile
- **Nix builds**: extracted from `version = "..."` in `default.nix`, or `CONTAINER_APP_VERSION` from the Dockerfile, or `dagger call nix-version` for nixpkgs packages

The [[add-container-version-sync-check]] pre-commit check ensures these declarations stay in sync with `service-versions.yaml`. See [[pin-container-versions]] for the work to ensure every container has a parseable version.

### Image Tag Format

| Build type | Tag format | Example |
|------------|-----------|---------|
| Dockerfile | `vX.Y.Z-<sha>` | `v2.2.17-abc1234` |
| Nix | `vX.Y.Z-<sha>-nix` | `v2.17.0-abc1234-nix` |

Where:
- `X.Y.Z` is the version of the most relevant bundled app (e.g., miniflux `2.2.17`, navidrome `0.60.3`)
- `<sha>` is the 7-char short commit SHA of the source tree used for the build

### What This Replaces

- The `container-tag-and-release` mise task is **replaced** by `container-build-and-release` — it triggers a manual workflow dispatch instead of creating git tags
- Git tags of the form `<container>-vX.Y.Z` are no longer used to trigger builds
- The `container-list` mise task displays the new tag format

## Key Files

| File | Change |
|------|--------|
| `.forgejo/workflows/build-container.yaml` | Replace tag trigger with path + dispatch triggers; compute version and SHA |
| `.forgejo/workflows/build-container-nix.yaml` | Same trigger changes; add `-nix` suffix to new tag format |
| `.dagger/src/blumeops_ci/main.py` | Accept SHA parameter; publish with new tag format |
| `mise-tasks/container-build-and-release` | New task replacing `container-tag-and-release`; triggers workflow dispatch |
| `mise-tasks/container-list` | Updated tag display for new format |
| `docs/how-to/deployment/build-container-image.md` | Updated documentation |

## Interaction With Other Prereqs

- **[[enforce-tag-immutability]]** — Commit SHA tags are inherently unique, reducing the scope of immutability enforcement
- **[[wire-ci-registry-auth]]** — Auth changes apply regardless of tagging scheme; no conflict

## Related

- [[harden-zot-registry]] — Parent goal
- [[enforce-tag-immutability]] — Complementary prereq (scope may narrow)
- [[build-container-image]] — How-to doc to update
