---
title: Harden Zot Registry
modified: 2026-02-20
status: active
requires:
  - register-zot-oidc-client
  - wire-ci-registry-auth
  - enforce-tag-immutability
  - adopt-commit-based-container-tags
tags:
  - how-to
  - zot
  - registry
  - security
---

# Harden Zot Registry

Enable OIDC + API key authentication on zot with anonymous pull preserved, and enforce tag immutability for version tags. This is the C2 Mikado root goal.

## Context

Zot currently has **no authentication** — security relies entirely on the Tailscale ACL boundary. Any tailnet client can push images, and tags are mutable.

Both prerequisites from the original plan are now complete:
- [[adopt-oidc-provider]] — Authentik is deployed and serving OIDC
- [[adopt-dagger-ci]] — Dagger handles container builds

## Core Change

Update `ansible/roles/zot/templates/config.json.j2` to add:

1. **`http.auth.openid`** — OIDC provider pointing to Authentik
2. **`http.auth.apikey: true`** — enable API key generation for CI
3. **`accessControl`** — anonymous read, authenticated write
4. **`externalUrl`** — `https://registry.ops.eblu.me` for OIDC callback redirects

## Key Files

| File | Purpose |
|------|---------|
| `ansible/roles/zot/templates/config.json.j2` | Zot config — add auth + access control |
| `ansible/roles/zot/defaults/main.yml` | New OIDC variables |
| `ansible/roles/zot/tasks/main.yml` | Deploy OIDC credentials file |

## Verification

- [ ] Anonymous pull works (`curl -sf https://registry.ops.eblu.me/v2/_catalog`)
- [ ] Unauthenticated push fails (401)
- [ ] OIDC browser login works (redirect to Authentik and back)
- [ ] API key push works (`docker login` with `zak_...` token)
- [ ] Pull-through caching still works
- [ ] `mise run services-check` passes

## Related

- [[register-zot-oidc-client]] — Prereq: register OIDC client in Authentik
- [[wire-ci-registry-auth]] — Prereq: update CI push paths with credentials
- [[enforce-tag-immutability]] — Prereq: prevent version tag overwrites
- [[adopt-commit-based-container-tags]] — Prereq: commit-SHA-based image tags
- [[agent-change-process]] — C2 methodology
