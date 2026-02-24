---
title: Migrate Grafana to Authentik
modified: 2026-02-24
last-reviewed: 2026-02-24
tags:
  - how-to
  - authentik
  - grafana
---

# Migrate Grafana to Authentik

Move Grafana's OIDC authentication from Dex to Authentik, then decommission Dex.

## What Was Done

### Blueprint loading fix

The Nix-built container hardcoded `blueprints_dir` to its Nix store path, making custom blueprints invisible. Fixed by adding a wrapper entrypoint that symlinks built-in blueprint dirs from `/nix/store/*authentik-django*/blueprints/` into `/blueprints/` at container start, with `AUTHENTIK_BLUEPRINTS_DIR=/blueprints` set in the container env. The `/blueprints` dir is created world-writable by `extraCommands` so user 65534 can write symlinks. Also fixed the `!Env` tag syntax in the blueprint YAML — `!Env` takes a scalar, not a sequence (`!Env FOO` not `!Env [FOO]`).

### Authentik configuration (via Blueprint)

- Blueprint at `argocd/manifests/authentik/configmap-blueprint.yaml` defines: `admins` group, Grafana OAuth2 provider (client ID: `grafana`), Grafana application, and policy binding
- Blueprint mounted as ConfigMap into worker at `/blueprints/custom/`
- `grafana-client-secret` stored in 1Password "Authentik (blumeops)"
- API token stored as `api-token` in same item

### Grafana configuration

- `argocd/manifests/grafana/configmap.yaml` updated to point at Authentik OIDC endpoints (`authentik.ops.eblu.me`)
- `argocd/manifests/grafana-config/external-secret-authentik-oauth.yaml` pulls client secret from "Authentik (blumeops)"
- Old Dex OAuth user deleted from Grafana (different `auth_id` caused "user already exists")

### Dex decommission

- ArgoCD app `dex` deleted (cascade removed k8s resources from ringtail)
- Removed `argocd/manifests/dex/`, `argocd/apps/dex.yaml`, `external-secret-dex-oauth.yaml`
- Removed `dex` entry from Caddy reverse proxy config

## Lessons Learned

- `buildLayeredImage`'s `extraCommands` can't access Nix store paths from `contents` — they're in separate layers. Use a runtime entrypoint wrapper for symlinks instead.
- Authentik `!Env` tag takes a bare scalar (`!Env FOO`), not a YAML sequence (`!Env [FOO]`). The `!Find` tag does use sequences.
- When migrating OAuth providers, the subject ID (`auth_id`) changes. Existing Grafana users must be deleted before the new provider can recreate them.

## Related

- [[deploy-authentik]] — Parent goal
- [[grafana]] — Grafana reference
