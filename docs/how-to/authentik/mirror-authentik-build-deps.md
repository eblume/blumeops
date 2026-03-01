---
title: Mirror Authentik Build Dependencies
modified: 2026-02-28
tags:
  - how-to
  - authentik
---

# Mirror Authentik Build Dependencies

Mirror the external repositories needed to build authentik from source onto the forge, ensuring full supply chain control.

## Context

Building authentik from source requires fetching code from three GitHub repositories. The main `goauthentik/authentik` repo is already mirrored, but two companion repos are not:

- **`goauthentik/client-go`** — Go API client bindings, versioned in lockstep with authentik (e.g. `v3.2026.2.0` matches `version/2026.2.0`). Used by the Go server build.
- **`authentik-community/django-rest-framework`** — Fork of DRF pinned to a specific commit. Authentik's Python backend requires this custom version. The upstream org name (`authentik-community`) differs from the main repo org (`goauthentik`), so the mirror name must be explicit.

## What to Do

1. Mirror `goauthentik/client-go`:
   ```fish
   mise run mirror-create https://github.com/goauthentik/client-go.git \
     --name authentik-client-go \
     --description "Go API client for authentik (lockstep versioned)"
   ```
2. Mirror `authentik-community/django-rest-framework`:
   ```fish
   mise run mirror-create https://github.com/authentik-community/django-rest-framework.git \
     --name authentik-django-rest-framework \
     --description "Authentik fork of Django REST Framework"
   ```
3. Verify both mirrors sync: check tags appear on forge

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-api-client-generation]] — Consumes client-go mirror
- [[authentik-python-backend-derivation]] — Consumes django-rest-framework mirror
