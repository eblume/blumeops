---
title: Harden Zot Registry
modified: 2026-10-22
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
the generation-rendered `darwin/indri/zot-config.json` (the in-repo copy of
the retired role's `config.json.j2` render, byte-identical to on-disk —
changed in the flake, applied by the auto-apply switch, V5-83 link 2,
eblume/blumeops#1782):

1. **`http.auth.openid`** — OIDC provider pointing to Authentik
   (`authentik.ops.eblu.me`); see [[register-zot-oidc-client]]
2. **`http.auth.apikey: true`** — API keys for CI service accounts
3. **`http.externalUrl`** — `https://registry.ops.eblu.me` for OIDC callbacks
4. **`http.accessControl`** — layered pull/push policy:
   - `anonymousPolicy: ["read"]` — anyone can pull
   - `defaultPolicy: ["read"]` — authenticated users in no listed group
   - `ci-artifacts` group: `["read", "create"]` — CI pushes new tags but
     cannot overwrite or delete (see [[enforce-tag-immutability]])
   - `admins` group: `["read", "create", "update", "delete"]` — break-glass
5. **`accessControl.metrics.anonymousPolicy: ["read"]`** — anonymous Prometheus/Alloy
   scraping. Since zot v2.1.18 (#4110/#4131) the metrics ACL is explicit: the
   old `users: [""]` trick no longer grants anonymous access and `/metrics`
   answers 401.

The OIDC issuer and external-URL settings are the same variables the retired
role's `defaults/main.yml` held (rendered into `darwin/indri/zot-config.json`);
the client credentials render via the seed-secrets manifest entry for
`~/.config/zot/oidc-credentials.json` (kind `op`, the role's template shape
wrapped in the entry's `format`). CI authenticates with the `ci-zot` API key
(see [[wire-ci-registry-auth]]).

## Related

- [[register-zot-oidc-client]] — OIDC client registration in Authentik
- [[wire-ci-registry-auth]] — CI push path wiring
- [[enforce-tag-immutability]] — Server-side via accessControl
- [[container-versioning]] — Commit-SHA-based image tags
