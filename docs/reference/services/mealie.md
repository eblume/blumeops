---
title: Mealie
modified: 2026-10-06
last-reviewed: 2026-07-22
tags:
  - service
  - recipes
---

# Mealie

Self-hosted recipe manager with a REST API. Part of the meal planning pipeline: Mealie stores categorized recipes, a planner script selects balanced meals, and [[ollama]] generates a unified cooking timeline.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://meals.ops.eblu.me |
| **Tailscale URL** | https://meals.tail8d86e.ts.net |
| **Namespace** | `mealie` |
| **Image** | `registry.ops.eblu.me/blumeops/mealie` (nix-built, self-pinned to nixos-unstable, see `containers/mealie/default.nix`) |
| **Database** | SQLite (local, at `/app/data/`) |
| **API Docs** | https://meals.ops.eblu.me/docs |
| **Upstream** | https://github.com/mealie-recipes/mealie |
| **Tracked upstream version** | `v3.29.0` |
| **Manifests** | `argocd/manifests/mealie-ringtail/` |

## Features

- Full REST API (FastAPI) for recipe CRUD, filtering by tag/category
- Structured recipe data: ingredients (quantity/unit/food), step-by-step instructions
- Built-in meal planning and shopping lists
- Recipe import from URLs
- API token auth for automation
- OIDC login via [[authentik]] (confidential client)

## Authentication

OIDC via [[authentik]] using a confidential client. Client secret stored in 1Password (`Authentik (blumeops)` / `mealie-client-secret`) and delivered via ExternalSecret. All Authentik users can log in; members of the `admins` group get Mealie admin privileges via `OIDC_ADMIN_GROUP`.

Since v3.21 Mealie requires the IdP to assert `email_verified=true`; Authentik's blueprint doesn't emit it, so the deployment sets `OIDC_REQUIRES_EMAIL_VERIFICATION=false` (accepted trust, eblume/blumeops#2095). Revisit when the Authentik blueprint emits the claim.

## Storage

- 2Gi PVC at `/app/data/` via `local-path` storageClassName (k3s local-path-provisioner)
- SQLite database (sufficient for single-user)
- Recipe images and assets stored alongside the database

## Backup

Two dumps via [[borgmatic]]'s `before_backup` hook, both in the operational tier (local sifaka backup, no offsite copy):

- `mealie.db`: a safe online `.backup` copy (Python's `sqlite3` module, via `kubectl exec`), staged at `~/.local/share/borgmatic/k8s-dumps-op/mealie.db`.
- `mealie-data.tar`: the full `/app/data` dir, recipe images under `recipes/<id>/images/` included, tarred in-pod (the image ships gnutar). The live `mealie.db*` is excluded from the tar.

To restore from a borg archive, see [[restore-from-borg]].

Before any Mealie bump that runs startup migrations (v3.26 and v3.29 are irreversible), take a full copy of the data dir first. The nightly `mealie-data.tar` covers this, but a fresh copy taken right before the bump is cheap insurance (the image ships `tar`, so `kubectl exec` can stream it):

```bash
kubectl -n mealie exec deploy/mealie -- tar cf - -C /app data > mealie-data-pre-<version>.tar
```

## Networking

| Endpoint | Reachable from |
|----------|----------------|
| `https://meals.ops.eblu.me` | Tailnet clients (via Caddy) |
| `https://meals.tail8d86e.ts.net` | Tailnet clients |
| `http://mealie.mealie.svc.cluster.local:9000` | In-cluster |

## Related

- [[plan-a-meal]] — Generate unified cooking timelines from meal plans
- [[authentik]] — OIDC identity provider
- [[ollama]] — LLM backend for meal timeline generation
- [[borgmatic]] — Data backup
