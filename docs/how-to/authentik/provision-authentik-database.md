---
title: Provision Authentik Database
modified: 2026-09-28
last-reviewed: 2026-09-28
tags:
  - how-to
  - authentik
  - postgresql
---

# Provision Authentik Database

Create a PostgreSQL database and user for Authentik on an existing CNPG
cluster.

> This run (2026-02-20) happened on the minikube `blumeops-pg` cluster. The
> [[retire-minikube]] series phase 2 (2026-06-11) moved the authentik DB to
> ringtail's `blumeops-pg` and relocated the manifests below to
> `argocd/manifests/databases-ringtail/`; see "Current State" after the steps.

## What Was Done

1. Added the `authentik` managed role to the `blumeops-pg` CNPG cluster — non-superuser with `createdb` and `login`
2. Created ExternalSecret `blumeops-pg-authentik` pulling the password from 1Password item "Authentik (blumeops)" field `postgresql-password`
3. Synced CNPG cluster — role reconciled with password set
4. Created the `authentik` database owned by the `authentik` user
5. Verified cross-cluster connectivity: ringtail pod → `pg.ops.eblu.me:5432` (Caddy L4)

## Current State

As of the [[retire-minikube]] phase 2 cutover:

- The role and ExternalSecret live in `argocd/manifests/databases-ringtail/`
  (`blumeops-pg.yaml`, `external-secret-authentik.yaml`) on ringtail's
  `blumeops-pg` cluster.
- The managed role is now `login` only — `createdb` was dropped; the database
  was pre-created at cutover (`CREATE DATABASE authentik OWNER authentik`).
- The Caddy L4 route `pg.ops.eblu.me:5432` retired with the minikube cluster;
  `blumeops-pg` is now on `pg.ops.eblu.me:5434` ([[connect-to-postgres]]).
  The app's host/port values live in the 1Password item, not in the repo.

## Resolved Questions

- **Hostname:** `pg.ops.eblu.me` via Caddy L4 plugin (not MagicDNS)
- **Permissions:** Non-superuser — Authentik manages its own schema via migrations

## Related

- [[authentik]] — Authentik reference
- [[postgresql]] — CNPG cluster reference
- [[connect-to-postgres]] — connecting to `pg.ops.eblu.me`
- [[retire-minikube]] — phase 2 moved the DB to ringtail
