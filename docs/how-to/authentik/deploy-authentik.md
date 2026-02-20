---
title: Deploy Authentik Identity Provider
modified: 2026-02-20
requires:
  - build-authentik-container
  - provision-authentik-database
  - create-authentik-secrets
tags:
  - how-to
  - authentik
  - security
  - oidc
---

# Deploy Authentik Identity Provider

Replace [[dex]] with [Authentik](https://goauthentik.io/) as the SSO identity provider. Authentik adds central user/group management, multi-protocol support (OIDC, SAML, LDAP), self-service flows, and an admin UI that Dex lacks. Forgejo remains the upstream identity source via OAuth2 connector.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Cluster** | [[ringtail]] (k3s) | IdP independent of main services cluster, same as Dex |
| **Database** | CNPG `blumeops-pg` on [[indri]] | Cross-cluster via Caddy L4 (`pg.ops.eblu.me`), no new operator needed |
| **Redis** | Co-deployed in authentik namespace | Required for caching/sessions/task queue |
| **Containers** | Nix-built (`dockerTools.buildLayeredImage`) | Supply chain control, consistent with Dex/ntfy pattern |
| **Manifests** | Kustomize (no Helm) | Consistent with all other BlumeOps services |
| **Networking** | Tailscale Ingress + Caddy reverse proxy | Same pattern as Dex |

## What Was Done

1. Built Nix container image (`v1.1.0-nix`) — `pkgs.authentik` + `coreutils` + `bashInteractive`
2. Created 1Password item "Authentik (blumeops)" with secret key and DB credentials
3. Provisioned `authentik` database and CNPG managed role on `blumeops-pg`
4. Deployed to ringtail k3s: server, worker, Redis (3 deployments)
5. ExternalSecret pulls config from 1Password
6. Tailscale Ingress at `authentik.tail8d86e.ts.net`
7. Caddy reverse proxy at `authentik.ops.eblu.me`

## URLs

- **Admin:** https://authentik.ops.eblu.me/if/admin/
- **Tailscale:** https://authentik.tail8d86e.ts.net

## Remaining Work

- **Initial setup:** Complete first-run wizard (create admin account)
- **Forgejo connector:** Configure OAuth2 source for Forgejo federation
- **Client migration:** Move Grafana (and future services) from Dex to Authentik
- **Cross-cluster metrics:** Prometheus on indri scraping authentik on ringtail
- **Dex decommission:** Separate effort after all OIDC clients migrate
- **Redis image:** Replace upstream `redis:7-alpine` with Nix-built container

## Related

- [[dex]] — Current IdP (to be replaced)
- [[federated-login]] — How authentication works across BlumeOps
- [[adopt-oidc-provider]] — Dex deployment plan (completed)
- [[ringtail]] — Target cluster
- [[agent-change-process]] — C2 methodology used for this change
