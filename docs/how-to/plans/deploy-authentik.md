---
title: Deploy Authentik Identity Provider
status: active
modified: 2026-02-20
tags:
  - how-to
  - plans
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
| **Database** | CNPG `blumeops-pg` on [[indri]] | Cross-cluster via Tailscale, no new operator needed |
| **Redis** | Co-deployed in authentik namespace | Required for caching/sessions/task queue |
| **Containers** | Nix-built (`dockerTools.buildLayeredImage`) | Supply chain control, consistent with Dex/ntfy pattern |
| **Manifests** | Kustomize (no Helm) | Consistent with all other BlumeOps services |
| **Networking** | Tailscale Ingress + Caddy reverse proxy | Same pattern as Dex |

## Open Questions

- **nixpkgs:** Verify `pkgs.authentik` exists. If not, packaging from source is a significant sub-task.
- **Cross-cluster metrics:** Prometheus on indri scraping authentik on ringtail needs a new pattern (Dex has no metrics collection today).
- **Dex decommission:** Separate effort after all OIDC clients migrate to Authentik.

## Related

- [[dex]] — Current IdP (to be replaced)
- [[federated-login]] — How authentication works across BlumeOps
- [[adopt-oidc-provider]] — Dex deployment plan (completed)
- [[ringtail]] — Target cluster
- [[agent-change-process]] — C2 methodology used for this change
