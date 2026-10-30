---
title: Authentik
modified: 2026-10-30
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

The `authentik_core.user`, `authentik_core.group`, and `authentik_policies.policybinding` entries are rendered from `argocd/manifests/authentik/principals.yaml` plus `retiring.yaml` by `mise run render-authentik-principals`; the Lint gate fails on drift ([[manage-authentik-principals]]). A `retiring.yaml` entry renders as an inactive record the blueprint keeps owning until the principal is deleted from live Authentik.

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

The item also holds an `api-token` field (an admin `api-token` for admin scripting); it is not synced into the cluster. `mise run reconcile-authentik-principals` reads it to diff live Authentik against the principal rosters and to empty the retiring queue ([[manage-authentik-principals]]). The token must be a current admin `api-token`; if it 403s, re-mint it in the Authentik UI (admin → account → API tokens) and update the field.

## Container Image

Nix-built via `dockerTools.buildLayeredImage`; the image needs `coreutils` and `bashInteractive` alongside the main package. The built-in blueprints (`default/`, `system/`, `migrations/`, …) are copied into `/blueprints/` as **real files** at image build time (`extraCommands`), next to the `custom/` ConfigMap mount. `AUTHENTIK_BLUEPRINTS_DIR=/blueprints` overrides the hardcoded Nix store path. They must not be symlinks: authentik's `retrieve_file` resolves each path and rejects anything outside `blueprints_dir` ("Invalid blueprint path"), and a scheduled `clear_failed_blueprints` then deletes the instance, so the failure is silent. For the same reason `authentik-django` is kept out of the image's `contents` (which would link its store tree into `/`), and the build fails if any symlink is left under `/blueprints`.

## Known limitation: client IP

Every authentik audit event records `client_ip` as indri's tailnet address `100.98.163.89`, not the real client. The path is client → indri Caddy → Tailscale ingress (ProxyGroup `ingress`) → authentik. The ingress replaces `X-Forwarded-For` with its own peer (indri), so the real client is lost at that hop. Authentik checks only the direct TCP peer (the ingress pod) against `TRUSTED_PROXY_CIDRS` and reads only `X-Forwarded-For`, so no alternate header helps without an upstream patch. Fixing it would mean routing around the ingress, a permanent exception judged not worth it for audit-log accuracy alone.

Do not rely on IP-based policy (reputation, GeoIP, IP expressions) in authentik: every event will show indri. The repo blueprints bind no such policies today.

## Related

- [[federated-login]] - How authentication works across BlumeOps
- [[grafana]] - First OIDC client
- [[provision-authentik-database]] - PostgreSQL database provisioning
- [[authentik-nix-build-components]] - Nix-based container build components
- [[mirror-authentik-build-deps]] - Supply chain mirrors for the build
- [[external-secrets]] - Secrets injection from 1Password
