---
title: Mirror Authentik Build Dependencies
modified: 2026-03-02
last-reviewed: 2026-03-02
tags:
  - how-to
  - authentik
---

# Mirror Authentik Build Dependencies

Mirror the external repositories needed to build authentik from source onto the forge, ensuring full supply chain control.

## Context

Building authentik from source requires fetching code from two GitHub repositories. The main `goauthentik/authentik` repo is already mirrored, but one companion repo needed mirroring:

- **`goauthentik/client-go`** — Go API client bindings, versioned in lockstep with authentik (e.g. `v3.2026.2.0` matches `version/2026.2.0`). Used by the Go server build.

Previously, `authentik-community/django-rest-framework` (a DRF fork) was also needed. As of authentik 2026.2.0, standard `djangorestframework` from PyPI is used instead — the fork mirror (`authentik-django-rest-framework`) can be archived.

## What to Do

1. Mirror `goauthentik/client-go`:
   ```fish
   mise run mirror-create https://github.com/goauthentik/client-go.git \
     --name authentik-client-go \
     --description "Go API client for authentik (lockstep versioned)"
   ```
2. Verify mirror syncs: check tags appear on forge

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-api-client-generation]] — Consumes client-go mirror
