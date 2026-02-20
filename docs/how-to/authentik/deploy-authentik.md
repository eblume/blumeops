---
title: Deploy Authentik Identity Provider
status: active
modified: 2026-02-20
requires:
  - build-authentik-container
  - provision-authentik-database
  - create-authentik-secrets
  - migrate-grafana-to-authentik
tags:
  - how-to
  - authentik
  - security
  - oidc
---

# Deploy Authentik Identity Provider

Replace [[dex]] with [Authentik](https://goauthentik.io/) as the SSO identity provider. Authentik is the **source of truth** for user identity in BlumeOps. Users are created and managed in Authentik; services authenticate against it via OIDC. Forgejo federation is deferred to a future effort (existing `eblume` account has extensive automations that need careful migration).

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Identity model** | Authentik is source of truth | Central user/group management, not Forgejo-upstream like Dex |
| **Cluster** | [[ringtail]] (k3s) | IdP independent of main services cluster, same as Dex |
| **Database** | CNPG `blumeops-pg` on [[indri]] | Cross-cluster via Caddy L4 (`pg.ops.eblu.me`), no new operator needed |
| **Redis** | Co-deployed in authentik namespace | Required for caching/sessions/task queue |
| **Containers** | Nix-built (`dockerTools.buildLayeredImage`) | Supply chain control, consistent with Dex/ntfy pattern |
| **Manifests** | Kustomize (no Helm) | Consistent with all other BlumeOps services |
| **Networking** | Tailscale Ingress + Caddy reverse proxy | Same pattern as Dex |
| **IaC** | Authentik Blueprints (YAML in ConfigMap) | GitOps-native, config stored in repo |

## What Was Done

1. Built Nix container image (`v1.1.0-nix`) — `pkgs.authentik` + `coreutils` + `bashInteractive`
2. Created 1Password item "Authentik (blumeops)" with secret key and DB credentials
3. Provisioned `authentik` database and CNPG managed role on `blumeops-pg`
4. Deployed to ringtail k3s: server, worker, Redis (3 deployments)
5. ExternalSecret pulls config from 1Password
6. Tailscale Ingress at `authentik.tail8d86e.ts.net`
7. Caddy reverse proxy at `authentik.ops.eblu.me`
8. Completed first-run wizard (admin account created)

## URLs

- **Admin:** https://authentik.ops.eblu.me/if/admin/
- **Tailscale:** https://authentik.tail8d86e.ts.net

## Future Work (not blocking this card)

- **Forgejo federation:** Make Forgejo an OIDC client of Authentik (deferred — needs careful `eblume` account migration)
- **Cross-cluster metrics:** Prometheus on indri scraping authentik on ringtail
- **Redis image:** Replace upstream `redis:7-alpine` with Nix-built container

## Related

- [[dex]] — Current IdP (to be replaced by [[migrate-grafana-to-authentik]])
- [[federated-login]] — How authentication works across BlumeOps
- [[adopt-oidc-provider]] — Dex deployment plan (completed)
- [[ringtail]] — Target cluster
- [[agent-change-process]] — C2 methodology used for this change
