---
title: Authentik
modified: 2026-02-20
tags:
  - service
  - security
  - oidc
---

# Authentik

OIDC identity provider for BlumeOps. Authentik is the **source of truth** for user identity — users are created and managed in Authentik, and services authenticate against it via OIDC.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://authentik.ops.eblu.me |
| **Admin UI** | https://authentik.ops.eblu.me/if/admin/ |
| **Tailscale URL** | https://authentik.tail8d86e.ts.net |
| **Namespace** | `authentik` |
| **Cluster** | k3s (ringtail) |
| **Image** | `registry.ops.eblu.me/blumeops/authentik:v1.1.2-nix` |
| **Manifests** | `argocd/manifests/authentik/` |
| **Container build** | `containers/authentik/default.nix` |

## Architecture

Authentik runs on [[ringtail]]'s k3s cluster, isolated from the main services on indri's minikube. This means the IdP is independent of the minikube cluster lifecycle.

Three deployments:
- **server** — HTTP/HTTPS interface, handles OIDC flows
- **worker** — Background tasks, blueprint application
- **redis** — Caching, sessions, task queue

## Database

Uses the shared CNPG `blumeops-pg` cluster on [[indri]], accessed cross-cluster via `pg.ops.eblu.me:5432`. Database `authentik` with managed role.

## Blueprints

Authentik configuration is managed via Blueprints (YAML) stored as a ConfigMap mounted into the worker at `/blueprints/custom/`. Current blueprints:

- **`common.yaml`** — shared identity resources (`admins` group)
- **`mfa.yaml`** — MFA enforcement on the default authentication flow (`not_configured_action: configure`)
- **`grafana.yaml`** — Grafana OAuth2 provider, application, and policy binding
- **`forgejo.yaml`** — Forgejo OAuth2 provider, application, and policy binding

Group membership is included in the `profile` scope claim (Authentik built-in). Services use `--group-claim-name groups` to read it.

Blueprint file: `argocd/manifests/authentik/configmap-blueprint.yaml`

## OIDC Clients

| Client | Status |
|--------|--------|
| [[grafana]] | Active |
| [[forgejo]] | Active |

Future clients: [[argocd]], [[miniflux]], [[zot]]

## Secrets

Injected via [[external-secrets]] from the "Authentik (blumeops)" 1Password item.

| 1Password Field | Purpose |
|-----------------|---------|
| `secret-key` | Authentik secret key |
| `db-password` | PostgreSQL password |
| `grafana-client-secret` | OIDC client secret for Grafana |
| `forgejo-client-secret` | OIDC client secret for Forgejo |
| `api-token` | Authentik API token |

## Container Image

Nix-built via `dockerTools.buildLayeredImage`. The entrypoint wrapper symlinks built-in blueprint directories from the Nix store into `/blueprints/` at runtime, allowing custom blueprints to coexist with defaults. `AUTHENTIK_BLUEPRINTS_DIR=/blueprints` overrides the hardcoded Nix store path.

## Related

- [[federated-login]] - How authentication works across BlumeOps
- [[grafana]] - First OIDC client
- [[deploy-authentik]] - Deployment how-to
- [[external-secrets]] - Secrets injection from 1Password
