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

## What Was Done So Far

### Completed

- API token created and stored in 1Password "Authentik (blumeops)" field `api-token`
- `grafana-client-secret` generated and stored in 1Password "Authentik (blumeops)"
- Blueprint YAML created at `argocd/manifests/authentik/configmap-blueprint.yaml` defining: admins group, Grafana OAuth2 provider, Grafana application, and policy binding
- Blueprint ConfigMap mounted into worker at `/blueprints/custom/`
- ExternalSecret updated to pull `grafana-client-secret` from 1Password
- Grafana `values.yaml` updated to point at Authentik OIDC endpoints
- `external-secret-authentik-oauth.yaml` created to replace `external-secret-dex-oauth.yaml`

### Blocked: Blueprint not loading

**Root cause:** The Nix-built container hardcodes `blueprints_dir` to `/nix/store/3h1g...authentik-django-2025.10.1/blueprints` in its `default.yml`. Custom blueprints mounted at `/blueprints/custom/` are invisible because that path is not on the search path.

**Fix options:**
1. Set env var `AUTHENTIK_BLUEPRINTS_DIR=/blueprints` and mount custom blueprints alongside copies/symlinks of the built-in ones — risky, could break built-in blueprints if the path doesn't include them.
2. Mount the custom blueprint ConfigMap directly into the Nix store blueprints path (e.g., `/nix/store/.../blueprints/custom/`) — fragile, path changes on rebuild.
3. Use the API to apply the configuration and skip file-based blueprints for now. Store the API calls in a mise task for reproducibility.
4. Patch the Nix container to set a writable `blueprints_dir` or create a wrapper that symlinks.

**Recommendation:** Option 4 (patch container) or option 1 (override env var) are the cleanest. Need to test whether `AUTHENTIK_BLUEPRINTS_DIR` is respected and whether built-in blueprints still load from the Nix store path when overridden.

## Notes

- Authentik API token stored as `api-token` in 1Password "Authentik (blumeops)".
- The `admins` group and Grafana provider/application created via API during investigation were cleaned up (deleted).

## Related

- [[deploy-authentik]] — Parent goal
- [[grafana]] — Grafana reference
- [[dex]] — Current IdP being replaced
