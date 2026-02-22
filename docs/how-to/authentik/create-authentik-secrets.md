---
title: Create Authentik Secrets
modified: 2026-02-22
last-reviewed: 2026-02-22
tags:
  - how-to
  - authentik
  - secrets
---

# Create Authentik Secrets

Create the 1Password item that the ExternalSecret references for Authentik configuration.

## What Was Done

1. Created 1Password item "Authentik (blumeops)" in vault `blumeops` (category: database) with fields:
   - `secret-key`: random 68-character base64 string (for `AUTHENTIK_SECRET_KEY`)
   - `postgresql-host`: `pg.ops.eblu.me`
   - `postgresql-port`: `5432`
   - `postgresql-name`: `authentik`
   - `postgresql-user`: `authentik`
   - `postgresql-password`: random 44-character base64 string
2. ExternalSecret `blumeops-pg-authentik` in databases namespace resolves successfully (verified during [[provision-authentik-database]])

## Notes

- The database password in this 1Password item is the same one used by the CNPG managed role via `external-secret-authentik.yaml`. Both the database ExternalSecret and the future Authentik deployment ExternalSecret reference the same 1Password item but different fields.
- The 1Password item has since grown with OIDC client secrets (`grafana-client-secret`, `forgejo-client-secret`, `zot-client-secret`, `jellyfin-client-secret`) and an `api-token` field, added during subsequent service integrations.

## Related

- [[deploy-authentik]] — Parent goal
- [[provision-authentik-database]] — Database provisioning (uses `postgresql-password` field)
