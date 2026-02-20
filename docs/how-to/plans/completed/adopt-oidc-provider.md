---
title: "Plan: Adopt OIDC Identity Provider"
modified: 2026-02-19
tags:
  - how-to
  - plans
  - security
  - oidc
---

# Plan: Adopt OIDC Identity Provider

> **Status:** Completed (2026-02-19) — Phase 1 (Dex + Grafana)
> **PR:** #222

## Background

BlumeOps services currently handle authentication independently — ArgoCD has its own admin password, Grafana has its own login, Forgejo has local accounts, and zot has no auth at all. There is no single sign-on, no centralized user management, and no way to issue scoped API keys or service tokens from a shared identity.

Adding an OpenID Connect (OIDC) identity provider gives BlumeOps a central authentication layer. Services delegate login to the IdP, and the IdP issues tokens that carry identity claims.

## Final Design

### Provider: Dex

Dex was chosen for its lightweight footprint (single Go binary, ~50MB RAM), config-driven operation (no web UI needed), and native Gitea/Forgejo connector support.

### Architecture

```
User Browser
    |
    v
Grafana (indri/minikube) --OIDC--> Dex (ringtail/k3s) --OAuth2--> Forgejo (indri/native)
    ^                                                                    |
    |                                                                    |
    +---------------------- redirect back with token -------------------+
```

Key design decisions:

- **Dex runs on ringtail's k3s cluster** — isolates the IdP from indri's minikube. If minikube goes down, Dex stays up. Recovery path: SSH → indri → ArgoCD local admin → fix.
- **Forgejo is the upstream identity source** — not static passwords. Users authenticate with their Forgejo account. Adding a user to SSO = creating a Forgejo account.
- **SQLite3 storage with emptyDir** — avoids a Kubernetes CRD storage bug (Go URL parsing issue with in-cluster API address). Pod restart invalidates sessions (users re-login), acceptable for a homelab.
- **NixOS-built container** — `containers/dex/default.nix` using `pkgs.dex-oidc`, consistent with the ntfy pattern.
- **Full config templated via ExternalSecret** — the entire `config.yaml` lives in the ExternalSecret template with secrets injected from 1Password. Nothing sensitive in git.
- **Cross-cluster communication** — Grafana reaches Dex via `https://dex.ops.eblu.me` (Caddy → Tailscale → ringtail), not k8s-internal DNS.

### Resolved Open Questions

- **Service dependency and recovery:** Dex on ringtail is independent of minikube. All services keep local admin logins as break-glass. If Dex goes down, users log in locally.
- **Dex vs Authentik:** Dex confirmed as the right choice. Config-driven, minimal resource usage, native Forgejo connector.
- **Storage backend:** SQLite3 (not Kubernetes CRDs). The CRD backend crashes due to a Go URL parsing bug with k3s's in-cluster API address. SQLite3 with emptyDir is simpler and avoids the issue.
- **User management scaling:** Forgejo connector solves this. Users are managed in Forgejo, not in Dex config files. Future option to add Google/GitHub connectors alongside Forgejo.
- **Tailscale ACL interaction:** Dex is tailnet-only via Caddy. Public access is a future consideration tied to exposing Forgejo publicly.

## Execution (as completed)

1. Created `containers/dex/default.nix` and built `dex:v1.0.0-nix`
2. Created 1Password item "Dex (blumeops)" with Forgejo OAuth2 credentials and Grafana client secret
3. Created OAuth2 application in Forgejo (Site Administration → Applications, confidential client, redirect URI `https://dex.ops.eblu.me/callback`)
4. Created ArgoCD app (`argocd/apps/dex.yaml`) targeting ringtail
5. Created k8s manifests: ExternalSecret, Deployment, Service, Ingress (5 files in `argocd/manifests/dex/`)
6. Added `dex.ops.eblu.me` to Caddy reverse proxy config
7. Created `grafana-dex-oauth` ExternalSecret for Grafana's OIDC client secret
8. Added `auth.generic_oauth` to Grafana's `values.yaml` with Dex endpoints
9. Fixed Grafana `root_url` from `grafana.tail8d86e.ts.net` to `grafana.ops.eblu.me` (OAuth state cookie mismatch)
10. Deployed and verified end-to-end SSO flow

## Verification (completed)

- [x] Container image exists: `dex:v1.0.0-nix` in registry
- [x] OIDC discovery endpoint returns valid configuration
- [x] Health check passes (`/healthz`)
- [x] Grafana login page shows "Sign in with Dex" button
- [x] OIDC flow: click Dex → Forgejo login → redirect back → logged in as Admin
- [x] Break-glass: local admin login still works
- [x] `mise run services-check` passes
- [x] ArgoCD shows dex app healthy and synced

## Key Files

| File | Purpose |
|------|---------|
| `containers/dex/default.nix` | NixOS container build |
| `argocd/apps/dex.yaml` | ArgoCD app (ringtail target) |
| `argocd/manifests/dex/` | K8s manifests (ExternalSecret, Deployment, Service, Ingress) |
| `argocd/manifests/grafana-config/external-secret-dex-oauth.yaml` | Grafana OIDC client secret |
| `argocd/manifests/grafana/values.yaml` | Grafana OIDC config (`auth.generic_oauth`) |
| `ansible/roles/caddy/defaults/main.yml` | Caddy reverse proxy entry |

## Future Phases

- **Phase 2:** ArgoCD OIDC (keep local admin, RBAC: `g, blume.erich@gmail.com, role:admin`)
- **Phase 3:** Forgejo OAuth2 provider integration (keep local accounts)
- **Phase 4:** Miniflux, Immich, other services
- **Phase 5:** Zot OIDC + hardening (per [[harden-zot-registry]])

## Related

- [[dex]] - Service reference card
- [[federated-login]] - How authentication works across BlumeOps
- [[harden-zot-registry]] - Future OIDC client
- [[forgejo]] - Upstream OAuth2 provider
- [[grafana]] - First OIDC client
