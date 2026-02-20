---
title: Federated Login
modified: 2026-02-19
last-reviewed: 2026-02-19
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

## The Solution: Dex + Forgejo

BlumeOps uses a two-layer federated authentication model:

1. **[[dex]]** is the OIDC identity provider (IdP). Services like [[grafana]] delegate their login flow to Dex using the OpenID Connect protocol. Dex issues standardized tokens that carry user identity.

2. **[[forgejo]]** is the upstream identity source. Dex doesn't store users itself — it delegates authentication to Forgejo via OAuth2. Users log in with their Forgejo credentials.

This separation is intentional. Dex handles the OIDC protocol (token issuance, discovery endpoints, client registration), while Forgejo handles user management (accounts, passwords, 2FA). Each does what it's good at.

## The Login Flow

When a user clicks "Sign in with Dex" on Grafana:

```
1. Grafana redirects browser to Dex    (dex.ops.eblu.me/auth)
2. Dex redirects browser to Forgejo    (forge.ops.eblu.me/login/oauth/authorize)
3. User logs in at Forgejo             (or is already logged in)
4. Forgejo redirects back to Dex       (dex.ops.eblu.me/callback)
5. Dex issues an OIDC token
6. Dex redirects back to Grafana       (grafana.ops.eblu.me/login/generic_oauth)
7. Grafana accepts the token, user is logged in
```

After step 3, if the user is already logged into Forgejo, the remaining steps happen instantly — it feels like a single click.

## Why Not Just Use Forgejo Directly?

Forgejo supports OAuth2 provider mode, so services could authenticate against it directly. Dex adds a layer of indirection, which provides:

- **Protocol translation** — Dex speaks OIDC (a standardized protocol) to downstream services. Not all services speak the same OAuth2 dialect that Forgejo does, but most speak OIDC.
- **Connector flexibility** — Dex can federate to multiple identity sources simultaneously. If a Google or GitHub connector is added later, downstream services don't change at all — they still talk to Dex.
- **Separation of concerns** — Forgejo is a git forge first. Its OAuth2 provider is a secondary feature. Dex is purpose-built for identity federation and handles edge cases (token refresh, JWKS rotation, discovery) more robustly.

For a single-user homelab, the indirection is admittedly overkill today. But it keeps the architecture clean for future growth — adding a second identity source or a new downstream service is a config change, not an architecture change.

## Break-Glass Access

Every service that uses Dex SSO also keeps a local admin login. If Dex goes down (or ringtail is offline), recovery works through:

1. SSH to indri
2. Log into ArgoCD with local admin password (from 1Password)
3. Fix whatever is broken

Dex is additive — it's a convenience layer, not a hard dependency. Services never lose their local auth capability.

## Cross-Cluster Communication

Dex runs on [[ringtail]]'s k3s cluster while most services run on indri's minikube. This is deliberate — the IdP is independent of the main services cluster. Communication happens via the Tailscale network:

- Grafana (minikube) → `dex.ops.eblu.me` → Caddy (indri) → Tailscale → Dex (ringtail k3s)
- Browser redirects go through `dex.ops.eblu.me` and `forge.ops.eblu.me`, both resolved via Caddy

No k8s-internal DNS crosses cluster boundaries. Everything uses the `*.ops.eblu.me` domain.

## Related

- [[dex]] - OIDC identity provider reference
- [[forgejo]] - Upstream OAuth2 provider
- [[grafana]] - First OIDC client
- [[security-model]] - Network security and access control
- [[adopt-oidc-provider]] - Implementation plan (completed)
