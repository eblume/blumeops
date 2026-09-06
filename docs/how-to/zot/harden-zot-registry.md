---
title: Harden Zot Registry
modified: 2026-08-21
last-reviewed: 2026-08-21
tags:
  - how-to
  - zot
  - registry
  - security
---

# Harden Zot Registry

[[zot]] runs with OIDC + API-key authentication and anonymous pull preserved,
with tag immutability enforced server-side via `accessControl`. Configured in
`ansible/roles/zot/templates/config.json.j2`:

1. **`http.auth.openid`** — OIDC provider pointing to Authentik
   (`authentik.ops.eblu.me`); see [[register-zot-oidc-client]]
2. **`http.auth.apikey: true`** — API keys for CI service accounts
3. **`http.externalUrl`** — `https://registry.ops.eblu.me` for OIDC callbacks
4. **`http.accessControl`** — layered pull/push policy:
   - `anonymousPolicy: ["read"]` — anyone can pull
   - `defaultPolicy: ["read"]` — authenticated users in no listed group
   - `artifact-workloads` group: `["read", "create"]` — CI pushes new tags but
     cannot overwrite or delete (see [[enforce-tag-immutability]])
   - `admins` group: `["read", "create", "update", "delete"]` — break-glass
5. **`accessControl.metrics.anonymousPolicy: ["read"]`** — anonymous Prometheus/Alloy
   scraping. Since zot v2.1.18 (#4110/#4131) the metrics ACL is explicit: the
   old `users: [""]` trick no longer grants anonymous access and `/metrics`
   answers 401.

OIDC issuer and external-URL variables live in `ansible/roles/zot/defaults/main.yml`;
client credentials render via `ansible/roles/zot/templates/oidc-credentials.json.j2`.
CI authenticates with the `zot-ci` API key (see [[wire-ci-registry-auth]]).

## Related

- [[register-zot-oidc-client]] — OIDC client registration in Authentik
- [[wire-ci-registry-auth]] — CI push path wiring
- [[enforce-tag-immutability]] — Server-side via accessControl
- [[container-versioning]] — Commit-SHA-based image tags
