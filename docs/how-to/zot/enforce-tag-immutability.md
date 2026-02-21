---
title: Enforce Tag Immutability
modified: 2026-02-20
status: active
tags:
  - how-to
  - zot
  - ci
---

# Enforce Tag Immutability

Prevent accidental overwrite of version tags during CI push.

## Approach

Push-side enforcement: before pushing a version tag, query `GET /v2/blumeops/<name>/tags/list` and fail if the tag already exists. Commit SHA tags are inherently unique and skip this check.

## Two Push Paths to Update

1. **Dagger path:** Add tag-existence check before `ctr.publish()` in `.dagger/src/blumeops_ci/main.py`
2. **Nix/skopeo path:** Add tag-existence check before `skopeo copy` in `.forgejo/workflows/build-container-nix.yaml`

## Key Files

| File | Purpose |
|------|---------|
| `.dagger/src/blumeops_ci/main.py` | Add pre-publish tag check |
| `.forgejo/workflows/build-container-nix.yaml` | Add pre-copy tag check |

## Notes

- After auth is enabled, the tag check API call may need auth too — or it can rely on anonymous read access from `anonymousPolicy: ["read"]`
- Only version tags (e.g., `v1.2.0`) need the check; commit SHA tags are unique by nature

## Verification

- [ ] Pushing a new version tag succeeds
- [ ] Pushing an existing version tag fails with a clear error
- [ ] Pushing a commit SHA tag always succeeds

## Related

- [[harden-zot-registry]] — Parent goal
