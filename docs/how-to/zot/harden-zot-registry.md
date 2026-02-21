---
title: Harden Zot Registry
modified: 2026-02-21
tags:
  - how-to
  - zot
  - registry
  - security
---

# Harden Zot Registry

OIDC + API key authentication on zot with anonymous pull preserved, and tag immutability enforced server-side via accessControl. This was a C2 Mikado goal — all prerequisites are now complete.

## What Was Done

Updated `ansible/roles/zot/templates/config.json.j2` with:

1. **`http.auth.openid`** — OIDC provider pointing to Authentik (`sso.ops.eblu.me`)
2. **`http.auth.apikey: true`** — API key generation for CI service accounts
3. **`http.accessControl`** — three-tier policy:
   - `anonymousPolicy: ["read"]` — anyone can pull
   - `artifact-workloads` group: `["read", "create"]` — CI can push new tags but cannot overwrite or delete (immutable tags)
   - `admins` group: `["read", "create", "update", "delete"]` — break-glass
4. **`http.externalUrl`** — `https://registry.ops.eblu.me` for OIDC callback redirects

CI authenticates via a zot API key generated from the `zot-ci` service account's OIDC session. The key is stored in 1Password and synced to Forgejo Actions secrets.

## Key Files

| File | Purpose |
|------|---------|
| `ansible/roles/zot/templates/config.json.j2` | Zot config with auth + access control |
| `ansible/roles/zot/defaults/main.yml` | OIDC issuer and external URL variables |
| `ansible/roles/zot/templates/oidc-credentials.json.j2` | OIDC client credentials |
| `.dagger/src/blumeops_ci/main.py` | `publish()` with registry auth |
| `.forgejo/workflows/build-container.yaml` | Dagger push with API key |
| `.forgejo/workflows/build-container-nix.yaml` | Skopeo push with API key |

## Verification

- [ ] Anonymous pull works (`curl -sf https://registry.ops.eblu.me/v2/_catalog`)
- [ ] Unauthenticated push fails (401)
- [ ] OIDC browser login works (redirect to Authentik and back)
- [ ] API key push works (`docker login` with zot API key)
- [ ] CI push succeeds (Dagger and Nix/skopeo paths)
- [ ] Pushing an existing version tag as CI user fails (no update permission)
- [ ] Admin can delete a tag if needed
- [ ] Pull-through caching still works
- [ ] `mise run services-check` passes

## Related

- [[register-zot-oidc-client]] — OIDC client registration in Authentik
- [[wire-ci-registry-auth]] — CI push path wiring
- [[enforce-tag-immutability]] — Folded into this card (server-side via accessControl)
- [[adopt-commit-based-container-tags]] — Commit-SHA-based image tags
- [[agent-change-process]] — C2 methodology
