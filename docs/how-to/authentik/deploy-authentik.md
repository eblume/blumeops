---
title: Deploy Authentik Identity Provider
modified: 2026-09-18
last-reviewed: 2026-09-18
tags:
  - how-to
  - authentik
  - security
  - oidc
---

# Deploy Authentik Identity Provider

Replace Dex with [Authentik](https://goauthentik.io/) as the SSO identity provider. Authentik is the **source of truth** for user identity in BlumeOps. Users are created and managed in Authentik; services authenticate against it via OIDC.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Identity model** | Authentik is source of truth | Central user/group management, not Forgejo-upstream like Dex |
| **Cluster** | [[ringtail]] (k3s) | Co-located with the BlumeOps services and the blumeops-pg database |
| **Database** | CNPG `blumeops-pg` on [[ringtail]] (`databases` namespace) | Shared by the BlumeOps apps — in-cluster at `blumeops-pg-rw.databases.svc.cluster.local`, cross-host via Caddy L4 `pg.ops.eblu.me:5434`; moved from minikube in [[retire-minikube]] |
| **Redis** | Co-deployed in authentik namespace | Required for caching/sessions/task queue |
| **Containers** | Nix-built (`dockerTools.buildLayeredImage`) | Supply chain control, consistent with Dex/ntfy pattern |
| **Manifests** | Kustomize (no Helm) | Consistent with all other BlumeOps services |
| **Networking** | Tailscale Ingress + Caddy reverse proxy | Same pattern as Dex |
| **IaC** | Authentik Blueprints (YAML in ConfigMap) | GitOps-native, config stored in repo |

## Deployment Process

1. Build a Nix container image — Authentik needs `coreutils` and `bashInteractive` alongside the main package; the entrypoint wrapper must symlink built-in blueprint directories so custom blueprints coexist with defaults
2. Create secrets in 1Password (secret key, DB credentials, OIDC client secrets)
3. Provision a dedicated database and managed role on the shared CNPG cluster ([[provision-authentik-database]])
4. Deploy server, worker, and Redis as separate deployments
5. Wire ExternalSecret to pull config from 1Password
6. Add Tailscale Ingress and Caddy reverse proxy entries
7. Complete the first-run wizard manually (creates admin account)
8. Migrate OIDC clients via Blueprints, then decommission the old IdP

## URLs

- **Admin:** https://authentik.ops.eblu.me/if/admin/
- **Tailscale:** https://authentik.tail8d86e.ts.net

## Related

- [[provision-authentik-database]] — the dedicated database and managed role
- [[build-authentik-from-source]] — the Nix image build
- [[authentik]] — OIDC identity provider
- [[federated-login]] — How authentication works across BlumeOps
- [[ringtail]] — Target cluster
- [[agent-change-process]] — how changes reach main
