---
title: Federated Login
modified: 2026-02-20
last-reviewed: 2026-02-20
tags:
  - explanation
  - security
  - oidc
---

# Federated Login

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

How authentication works across BlumeOps services, and why it's designed this way.

## The Problem

Without centralized authentication, every service manages its own users independently. Grafana has an admin password, ArgoCD has a different admin password, Forgejo has local accounts, and zot has no auth at all. This creates several problems:

- **Password sprawl** — different credentials for every service, all stored separately in 1Password
- **No onboarding path** — adding a collaborator means creating accounts in every service individually
- **No single sign-on** — logging into Grafana doesn't help you access ArgoCD
- **Inconsistent security** — some services have auth, some don't, and there's no central audit trail

## The Solution: Authentik

BlumeOps uses [[authentik]] as the central OIDC identity provider. Authentik is the **source of truth** for user identity — users are created and managed in Authentik, and services authenticate against it via OpenID Connect.

This is a deliberate choice: Authentik provides a full-featured identity management UI, Blueprint-driven GitOps configuration, and support for multiple authentication protocols. Services like [[grafana]] delegate their login flow to Authentik using OIDC, and Authentik issues standardized tokens that carry user identity.

## The Login Flow

When a user clicks "Sign in with Authentik" on Grafana:

```
1. Grafana redirects browser to Authentik   (authentik.ops.eblu.me/application/o/authorize/)
2. User logs in at Authentik                 (or is already logged in)
3. Authentik issues an OIDC token
4. Authentik redirects back to Grafana       (grafana.ops.eblu.me/login/generic_oauth)
5. Grafana accepts the token, user is logged in
```

If the user is already logged into Authentik, the flow happens instantly — it feels like a single click.

## Break-Glass Access

Every service that uses Authentik SSO also keeps a local admin login. If Authentik goes down (or ringtail is offline), recovery works through:

1. SSH to indri
2. Log into ArgoCD with local admin password (from 1Password)
3. Fix whatever is broken

Authentik is additive — it's a convenience layer, not a hard dependency. Services never lose their local auth capability.

## Cross-Cluster Communication

Authentik runs on [[ringtail]]'s k3s cluster while most services run on indri's minikube. This is deliberate — the IdP is independent of the main services cluster. Communication happens via the Tailscale network:

- Grafana (minikube) → `authentik.ops.eblu.me` → Caddy (indri) → Tailscale → Authentik (ringtail k3s)
- Browser redirects go through `authentik.ops.eblu.me`, resolved via Caddy

No k8s-internal DNS crosses cluster boundaries. Everything uses the `*.ops.eblu.me` domain.

## Future Work

- **Forgejo OIDC:** Make Forgejo an OIDC client of Authentik (deferred — existing `eblume` account needs careful migration)
- **Additional services:** ArgoCD, Miniflux, Immich, Zot (see [[harden-zot-registry]])

## Related

- [[authentik]] - OIDC identity provider reference
- [[grafana]] - First OIDC client
- [[security-model]] - Network security and access control
- [[deploy-authentik]] - Deployment how-to
