---
title: Enforce Tag Immutability
modified: 2026-02-21
tags:
  - how-to
  - zot
  - ci
---

# Enforce Tag Immutability

Prevent accidental overwrite of version tags during CI push.

## Resolution

Tag immutability is enforced server-side via `accessControl` policies in [[harden-zot-registry]], not by client-side push checks. The three-tier access model makes push-side enforcement unnecessary:

- **Anonymous:** `["read"]` — pull only, no push at all
- **`artifact-workloads` group (CI):** `["read", "create"]` — can push new tags but cannot overwrite or delete existing ones
- **Admins:** `["read", "create", "delete"]` — break-glass for removing bad images

Since CI only has `create` (not `update`), pushing an existing version tag is rejected by zot itself. Commit SHA tags are inherently unique and never collide.

This approach requires authentication to be meaningful — without auth, everyone is anonymous. The requirements are therefore part of the root [[harden-zot-registry]] goal's `accessControl` configuration.

## Related

- [[harden-zot-registry]] — Parent goal (includes this requirement)
