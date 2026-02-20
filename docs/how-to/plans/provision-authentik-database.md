---
title: Provision Authentik Database
status: active
modified: 2026-02-20
tags:
  - how-to
  - plans
  - authentik
  - postgresql
---

# Provision Authentik Database

Create a PostgreSQL database and user for Authentik on the existing CNPG cluster.

## Context

Discovered while attempting [[deploy-authentik]]: Authentik requires a PostgreSQL database, but no `authentik` database exists on `blumeops-pg`. The CNPG cluster runs on [[indri]] (minikube) and is reachable from [[ringtail]] via Tailscale at `blumeops-pg-rw.databases.svc:5432` or the Tailscale endpoint.

## What to Do

1. Create database `authentik` and user `authentik` on the CNPG cluster
2. Store credentials in 1Password (part of the "Authentik (blumeops)" item)
3. Verify cross-cluster connectivity: ringtail pod → indri postgres via Tailscale

## Open Questions

- What Tailscale hostname does the CNPG cluster expose? Need to check if there's a Tailscale Ingress for postgres or if we need to use the MagicDNS name directly.
- Should the database user have limited permissions or superuser access?

## Related

- [[deploy-authentik]] — Parent goal
- [[postgresql]] — CNPG cluster reference
