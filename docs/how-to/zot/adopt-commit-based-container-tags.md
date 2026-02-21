---
title: Adopt Commit-Based Container Tags
modified: 2026-02-20
status: active
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
2. **Manual workflow dispatch** — for ad-hoc builds (e.g., testing on a branch). Accepts two inputs:
   - `container` (required) — which container to build
   - `ref` (optional, string) — the source commit SHA to build, defaulting to `HEAD` of `main`

Both the Dockerfile and Nix workflows fire for each trigger, each bailing out if the container lacks the relevant build file (same as today).

### Version Source

Each container declares the version of its primary bundled app. The mechanism for declaring this (e.g., a `VERSION` file, parsing a Dockerfile `ARG`, or a convention per container) should be determined during implementation.

### Image Tag Format

The registry image tag encodes the app version and the exact source commit:

| Scenario | Dockerfile tag | Nix tag |
|----------|---------------|---------|
| Main branch build | `vX.Y.Z-<sha>` and `vX.Y.Z-<sha>-main` | `vX.Y.Z-<sha>-nix` and `vX.Y.Z-<sha>-main-nix` |
| Manual dispatch | `vX.Y.Z-<sha>` | `vX.Y.Z-<sha>-nix` |

Where:
- `X.Y.Z` is the version of the most relevant bundled app (e.g., miniflux `2.2.5`, navidrome `0.53.3`)
- `<sha>` is the short commit SHA of the source tree used for the build

The `-main` tag indicates a build from the merged main branch, suitable for production deployment. Non-main builds (manual dispatch) omit this suffix.

### What This Replaces

- The `container-tag-and-release` mise task is **renamed and repurposed** to `container-build-and-release` — it triggers a manual workflow dispatch instead of creating git tags. It sends the current `HEAD` SHA so that it works from any branch, not just main
- Git tags of the form `<container>-vX.Y.Z` are no longer used to trigger builds
- The `container-list` mise task should be updated to display the new tag format

## Key Files

| File | Change |
|------|--------|
| `.forgejo/workflows/build-container.yaml` | Replace tag trigger with path + dispatch triggers; compute version and SHA; push multiple tags |
| `.forgejo/workflows/build-container-nix.yaml` | Same trigger changes; add `-nix` suffix to new tag format |
| `.dagger/src/blumeops_ci/main.py` | Accept SHA parameter; publish with new tag format |
| `mise-tasks/container-build-and-release` | Rename from `container-tag-and-release`; trigger workflow dispatch with current HEAD SHA |
| `mise-tasks/container-list` | Update tag display for new format |
| `docs/how-to/deployment/build-container-image.md` | Document new workflow |

## Interaction With Other Prereqs

- **[[enforce-tag-immutability]]** — Commit SHA tags are inherently unique, reducing the scope of immutability enforcement to the `-main` rolling tag (if that is treated as mutable/latest) or eliminating it entirely if `-main` tags are also SHA-qualified (as proposed above)
- **[[wire-ci-registry-auth]]** — Auth changes apply regardless of tagging scheme; no conflict

## Verification

- [ ] Push to main modifying `containers/nettest/` triggers both Docker and Nix builds
- [ ] Resulting image tags match `vX.Y.Z-<sha>` and `vX.Y.Z-<sha>-main` format
- [ ] Nix tags have `-nix` suffix
- [ ] Manual workflow dispatch builds with correct tags (no `-main` suffix)
- [ ] `mise run container-list` shows new tag format
- [ ] Existing deployments referencing old tags still work (images not deleted)

## Related

- [[harden-zot-registry]] — Parent goal
- [[enforce-tag-immutability]] — Complementary prereq (scope may narrow)
- [[build-container-image]] — How-to doc to update
