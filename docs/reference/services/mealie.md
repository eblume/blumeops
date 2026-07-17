---
title: Mealie
modified: 2026-07-16
last-reviewed: 2026-07-16
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
| **Image** | `registry.ops.eblu.me/blumeops/mealie` (built from source) |
| **Database** | SQLite (local, at `/app/data/`) |
| **API Docs** | https://meals.ops.eblu.me/docs |
| **Upstream** | https://github.com/mealie-recipes/mealie |
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

## Storage

- 2Gi PVC at `/app/data/` via `local-path` storageClassName (k3s local-path-provisioner)
- SQLite database (sufficient for single-user)
- Recipe images and assets stored alongside the database

## Backup

SQLite database backed up via [[borgmatic]]'s `before_backup` hook. Borgmatic runs `kubectl exec` to create a safe `.backup` copy (via Python's `sqlite3` module), then `kubectl cp` to the host. The dump lands in `~/.local/share/borgmatic/k8s-dumps/mealie.db` and is included in both local (sifaka) and offsite (BorgBase) backups.

To restore from a borg archive, see [[restore-from-borg]].

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
