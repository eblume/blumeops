---
title: Enforce Tag Immutability
modified: 2026-11-11
last-reviewed: 2026-11-11
tags:
  - how-to
  - zot
  - ci
---

# Enforce Tag Immutability

Prevent accidental overwrite of version tags during CI push.

## Resolution

Tag immutability is enforced server-side via `accessControl` policies in [[harden-zot-registry]], not by client-side push checks. Every non-admin identity holds `create` and not `update`:

- **Anonymous:** `["read"]` — pull only, no push at all
- **`ci-artifacts` group (base CI, `ci-zot`):** `["read", "create"]` — can push new tags but cannot overwrite or delete existing ones
- **Per-repo release identities** (`ci-zot-talos`, `ci-zot-horkos`, `horkos-zot`): `["create"]` on their own image path only
- **Admins:** `["read", "create", "update", "delete"]` — break-glass for removing bad images

zot refuses a manifest PUT to an existing tag even when the digest is identical, so a push that would overwrite a tag is rejected by zot itself. Commit SHA tags are inherently unique and never collide.

Release re-runs are still idempotent. Before pushing, the release workflows read the tag's image config: the same image config skips the push, and a different one fails the run. The cv tarball push (`push_oci_artifact`, horkos publisher) is the exception: it compares the manifest digest it builds itself. See [[zot]] for the identity table.

This approach requires authentication to be meaningful — without auth, everyone is anonymous. The requirements are therefore part of the root [[harden-zot-registry]] goal's `accessControl` configuration.

## Related

- [[harden-zot-registry]] — Parent goal (includes this requirement)
- [[zot]] — Zot registry service reference
