---
title: Authentik
modified: 2026-09-20
last-reviewed: 2026-09-20
tags:
  - service
  - security
  - oidc
---

# Authentik

OIDC identity provider for BlumeOps. Authentik is the **source of truth** for user identity — users are created and managed in Authentik (not Forgejo-upstream like its predecessor Dex), and services authenticate against it via OIDC.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://authentik.ops.eblu.me |
| **Admin UI** | https://authentik.ops.eblu.me/if/admin/ |
| **Tailscale URL** | https://authentik.tail8d86e.ts.net |
| **Namespace** | `authentik` |
| **Cluster** | k3s (ringtail) |
| **Manifests** | `argocd/manifests/authentik/` |
| **Container build** | `containers/authentik/default.nix` |

## Architecture

Authentik runs on [[ringtail]]'s k3s cluster alongside the other BlumeOps workloads, and shares that cluster's `blumeops-pg` database.

Three deployments:
- **server** — HTTP/HTTPS interface, handles OIDC flows
- **worker** — Background tasks, blueprint application
- **redis** — Caching, sessions, task queue

## Database

Uses the shared CNPG `blumeops-pg` cluster in the `databases` namespace on [[ringtail]]'s k3s — in-cluster at `blumeops-pg-rw.databases.svc.cluster.local`, cross-host via Caddy L4 `pg.ops.eblu.me:5434`. The cluster sat on indri's minikube before it was retired in 2026-06 ([[retire-minikube]]). Database `authentik` with managed role ([[provision-authentik-database]]).

## Blueprints

Authentik configuration is managed via Blueprints (YAML) stored as a ConfigMap mounted into the worker at `/blueprints/custom/`. Current blueprints:

- **`common.yaml`** — shared identity resources (`admins` group)
- **`mfa.yaml`** — MFA enforcement on the default authentication flow (`not_configured_action: configure`)
- One blueprint per OIDC client (provider, application, and policy binding): `grafana.yaml`, `forgejo.yaml`, `zot.yaml`, `argocd.yaml`, `jellyfin.yaml`, `mealie.yaml`, `paperless.yaml`, `heph.yaml`

Group membership is included in the `profile` scope claim (Authentik built-in). Services use `--group-claim-name groups` to read it.

Blueprint file: `argocd/manifests/authentik/configmap-blueprint.yaml`

YAML tag gotcha: `!Env` takes a bare scalar (`!Env AUTHENTIK_GRAFANA_CLIENT_SECRET`), not a sequence — `!Find` is the one that uses sequences.

## OIDC Clients

| Client | Type |
|--------|------|
| [[grafana]] | Confidential |
| [[forgejo]] | Confidential |
| [[zot]] | Confidential |
| [[argocd]] | Public (PKCE, shared by web UI and CLI) |
| [[jellyfin]] | Confidential |
| [[mealie]] | Confidential |
| [[paperless]] | Confidential |
| [[talos]] | Confidential |
| heph | Public (PKCE, with `offline_access` for spoke sync refresh tokens) |

Future clients: [[miniflux]]

## Secrets

Injected via [[external-secrets]] from the "Authentik (blumeops)" 1Password item.

| 1Password Field | Purpose |
|-----------------|---------|
| `secret-key` | Authentik secret key |
| `postgresql-host` / `-port` / `-name` / `-user` / `-password` | PostgreSQL connection |
| `<client>-client-secret` | OIDC client secret, one per confidential client (grafana, forgejo, zot, jellyfin, mealie, paperless, warrant, talos) |

The item also holds an `api-token` field (Authentik API access for admin scripting); it is not synced into the cluster.

## Container Image

Nix-built via `dockerTools.buildLayeredImage`; the image needs `coreutils` and `bashInteractive` alongside the main package. The entrypoint wrapper symlinks built-in blueprint directories from the Nix store into `/blueprints/` at runtime, allowing custom blueprints to coexist with defaults (`buildLayeredImage`'s `extraCommands` can't see store paths from `contents` — separate layers — so the symlinks are made at container start, not build time). `AUTHENTIK_BLUEPRINTS_DIR=/blueprints` overrides the hardcoded Nix store path.

## Related

- [[federated-login]] - How authentication works across BlumeOps
- [[grafana]] - First OIDC client
- [[provision-authentik-database]] - PostgreSQL database provisioning
- [[build-authentik-from-source]] - Nix-based container build
- [[mirror-authentik-build-deps]] - Supply chain mirrors for the build
- [[external-secrets]] - Secrets injection from 1Password
