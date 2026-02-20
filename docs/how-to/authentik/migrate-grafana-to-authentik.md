---
title: Migrate Grafana to Authentik
status: active
modified: 2026-02-20
tags:
  - how-to
  - authentik
  - grafana
---

# Migrate Grafana to Authentik

Move Grafana's OIDC authentication from Dex to Authentik, then decommission Dex.

## Context

Discovered while attempting [[deploy-authentik]]: Authentik is deployed and running, but no services use it yet. Grafana is the first client to migrate. Once Grafana is off Dex, Dex has no remaining clients and can be decommissioned.

## What to Do

### Authentik configuration (via API, then capture as Blueprint)

1. Create an `admins` group in Authentik
2. Ensure user `blume.erich@gmail.com` is in the `admins` group
3. Create an OAuth2/OIDC provider for Grafana (client ID: `grafana`, redirect URIs for both `grafana.ops.eblu.me` and `grafana.tail8d86e.ts.net`)
4. Create an Application for Grafana linked to the provider, gated to the `admins` group
5. Store the client secret in 1Password "Authentik (blumeops)" as `grafana-client-secret`
6. Capture the configuration as an Authentik Blueprint YAML in the manifests

### Grafana configuration

1. Update `argocd/manifests/grafana/values.yaml` — change `auth.generic_oauth` from Dex to Authentik endpoints
2. Replace `external-secret-dex-oauth.yaml` with one that pulls from "Authentik (blumeops)" instead of "Dex (blumeops)"
3. Sync Grafana via ArgoCD and verify SSO login works

### Dex decommission

1. Delete ArgoCD app `dex`
2. Remove `argocd/manifests/dex/` and `argocd/apps/dex.yaml`
3. Remove `dex` entry from Caddy reverse proxy (`ansible/roles/caddy/defaults/main.yml`)
4. Provision Caddy to apply the change

## Notes

- Requires an Authentik API token — create one in Admin > System > Tokens, store as `api-token` field in "Authentik (blumeops)" 1Password item.

## Related

- [[deploy-authentik]] — Parent goal
- [[grafana]] — Grafana reference
- [[dex]] — Current IdP being replaced
