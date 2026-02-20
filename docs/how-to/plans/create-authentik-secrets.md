---
title: Create Authentik Secrets
status: active
modified: 2026-02-20
tags:
  - how-to
  - plans
  - authentik
  - secrets
---

# Create Authentik Secrets

Create the 1Password item that the ExternalSecret references for Authentik configuration.

## Context

Discovered while attempting [[deploy-authentik]]: the ExternalSecret references 1Password item "Authentik (blumeops)" which doesn't exist. Without it, the `authentik-config` Kubernetes secret won't be created and pods can't start.

## What to Do

1. Generate a random secret key for Authentik (`AUTHENTIK_SECRET_KEY`)
2. Create 1Password item "Authentik (blumeops)" in vault `blumeops` with fields:
   - `secret-key`: random 50+ character string
   - `postgresql-host`: Tailscale-accessible postgres hostname
   - `postgresql-port`: `5432`
   - `postgresql-name`: `authentik`
   - `postgresql-user`: `authentik`
   - `postgresql-password`: the password from [[provision-authentik-database]]
3. Verify the ExternalSecret can resolve on ringtail's cluster

## Notes

- This partially depends on [[provision-authentik-database]] for the postgres password, but the 1Password item structure and secret key can be created independently.

## Related

- [[deploy-authentik]] — Parent goal
- [[provision-authentik-database]] — Source of database credentials
