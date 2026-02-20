---
title: Dex
modified: 2026-02-19
tags:
  - service
  - security
  - oidc
---

# Dex

OIDC identity provider for BlumeOps. Dex federates authentication — downstream services (Grafana, future ArgoCD, etc.) delegate login to Dex, and Dex delegates to [[forgejo]] as the upstream OAuth2 provider.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://dex.ops.eblu.me |
| **Tailscale URL** | https://dex.tail8d86e.ts.net |
| **Namespace** | `dex` |
| **Cluster** | k3s (ringtail) |
| **Image** | `registry.ops.eblu.me/blumeops/dex:v1.0.0-nix` |
| **Upstream** | https://github.com/dexidp/dex |
| **Manifests** | `argocd/manifests/dex/` |
| **Container build** | `containers/dex/default.nix` |

## Architecture

Dex runs on [[ringtail]]'s k3s cluster, isolated from the main services on indri's minikube. This means the IdP is independent of the minikube cluster lifecycle — if minikube goes down, Dex stays up and services can still authenticate once restored.

```
User Browser
    |
    v
Grafana (indri/minikube) --OIDC--> Dex (ringtail/k3s) --OAuth2--> Forgejo (indri/native)
    ^                                                                    |
    |                                                                    |
    +---------------------- redirect back with token -------------------+
```

Cross-cluster communication works because Grafana reaches Dex via `https://dex.ops.eblu.me` (Caddy → Tailscale → ringtail), not k8s-internal DNS.

## Identity Source

Dex uses a **Gitea connector** pointed at [[forgejo]] (`https://forge.ops.eblu.me`). Users authenticate with their Forgejo credentials. There are no static passwords — user management happens entirely in Forgejo.

This means adding a new user to BlumeOps SSO is just creating a Forgejo account.

## Storage

SQLite3 with an `emptyDir` volume. This stores refresh tokens and auth codes. A pod restart invalidates active sessions (users re-login), which is acceptable for a homelab. No PVC needed.

## OIDC Clients

| Client | Redirect URIs | Status |
|--------|---------------|--------|
| [[grafana]] | `grafana.ops.eblu.me/login/generic_oauth`, `grafana.tail8d86e.ts.net/login/generic_oauth` | Active |

Future clients: [[argocd]], [[forgejo]], [[miniflux]], [[zot]]

## Secrets

All sensitive configuration is injected via [[external-secrets]] from the "Dex (blumeops)" 1Password item. The entire `config.yaml` is templated in the ExternalSecret — nothing sensitive is committed to git.

| 1Password Field | Purpose |
|-----------------|---------|
| `forgejo-client-id` | OAuth2 app client ID from Forgejo |
| `forgejo-client-secret` | OAuth2 app client secret from Forgejo |
| `grafana-client-secret` | OIDC client secret for Grafana |

## Endpoints

| Path | Purpose |
|------|---------|
| `/.well-known/openid-configuration` | OIDC discovery |
| `/auth` | Authorization (browser redirect) |
| `/token` | Token exchange |
| `/userinfo` | User info |
| `/keys` | JWKS (public keys) |
| `/callback` | OAuth2 callback from Forgejo |
| `/healthz` | Health check |

## Related

- [[federated-login]] - How authentication works across BlumeOps
- [[forgejo]] - Upstream OAuth2 provider
- [[grafana]] - First OIDC client
- [[routing]] - How Dex is exposed via Caddy
- [[external-secrets]] - Secrets injection from 1Password
