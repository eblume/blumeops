---
title: Mirror Authentik Build Dependencies
modified: 2026-10-01
last-reviewed: 2026-10-01
tags:
  - how-to
  - authentik
---

# Mirror Authentik Build Dependencies

Mirror the external repositories needed to build authentik from source onto the forge, ensuring full supply chain control.

## Context

Building authentik from source fetches two GitHub repos — `goauthentik/authentik` and `goauthentik/client-go` — from forge mirrors via `pkgs.fetchgit` with SRI hashes (URLs centralized in `containers/authentik/sources.nix`), for supply chain control. The main repo was already mirrored; one companion repo needed mirroring:

- **`goauthentik/client-go`** — Go API client bindings, versioned in lockstep with authentik (e.g. `v3.2026.2.0` matches `version/2026.2.0`). Used by the Go server build.

Previously, `goauthentik/django-rest-framework` (authentik's DRF fork) was also required. Since authentik [PR 16594](https://github.com/goauthentik/authentik/pull/16594) (2025-10-21) it is dropped in favor of standard `djangorestframework` 3.16.1 from PyPI, so no forge mirror of the fork was ever created (verified 2026-09-29 — no such repo in the `mirrors/` org; the upstream fork itself is now archived).

## What to Do

1. Mirror `goauthentik/client-go`:
   ```fish
   mise run mirror-create https://github.com/goauthentik/client-go.git \
     --name authentik-client-go \
     --description "Go API client for authentik (lockstep versioned)"
   ```
   New mirrors land in the `mirrors/` Forgejo org.
2. Verify the mirror syncs: check tags appear on forge (e.g. `mirrors/authentik-client-go` carries the `v3.2026.x.y` tags)

Done as of 2026-09-29: the mirror is live and `containers/authentik/sources.nix` fetches `client-go-src` from it (currently pinned to `v3.2026.2.1`).

## Related

- [[authentik]] — Authentik reference
- [[authentik-nix-build-components]] — Consumes client-go mirror
- [[manage-forgejo-mirrors]] — Mirror creation, PAT rotation
