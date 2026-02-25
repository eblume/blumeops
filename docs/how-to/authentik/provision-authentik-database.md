---
title: Provision Authentik Database
modified: 2026-02-20
last-reviewed: 2026-02-25
tags:
  - how-to
  - authentik
  - postgresql
---

# Provision Authentik Database

Create a PostgreSQL database and user for Authentik on the existing CNPG cluster.

## What Was Done

1. Added `authentik` managed role to `blumeops-pg` CNPG cluster (`argocd/manifests/databases/blumeops-pg.yaml`) — non-superuser with `createdb` and `login`
2. Created ExternalSecret `blumeops-pg-authentik` pulling password from 1Password item "Authentik (blumeops)" field `postgresql-password`
3. Synced CNPG cluster — role reconciled with password set
4. Created `authentik` database owned by `authentik` user
5. Verified cross-cluster connectivity: ringtail pod → `pg.ops.eblu.me:5432` (Caddy L4)

## Resolved Questions

- **Hostname:** `pg.ops.eblu.me` via Caddy L4 plugin (not MagicDNS)
- **Permissions:** Non-superuser with `createdb` — Authentik manages its own schema via migrations

## Related

- [[deploy-authentik]] — Parent goal
- [[postgresql]] — CNPG cluster reference
