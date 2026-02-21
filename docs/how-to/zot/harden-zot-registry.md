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

OIDC + API key authentication on zot with anonymous pull preserved, and tag immutability enforced server-side via accessControl. Completed as a C2 Mikado goal across PRs #236 and #237.

## What Was Done

Updated `ansible/roles/zot/templates/config.json.j2` with:

1. **`http.auth.openid`** — OIDC provider pointing to Authentik (`authentik.ops.eblu.me`)
2. **`http.auth.apikey: true`** — API key generation for CI service accounts
3. **`http.accessControl`** — three-tier policy:
   - `anonymousPolicy: ["read"]` — anyone can pull
   - `artifact-workloads` group: `["read", "create"]` — CI can push new tags but cannot overwrite or delete (immutable tags)
   - `admins` group: `["read", "create", "update", "delete"]` — break-glass
4. **`http.externalUrl`** — `https://registry.ops.eblu.me` for OIDC callback redirects
5. **`accessControl.metrics.users: [""]`** — allows anonymous Prometheus/Alloy scraping

## Key Files

| File | Purpose |
|------|---------|
| `ansible/roles/zot/templates/config.json.j2` | Zot config with auth + access control |
| `ansible/roles/zot/defaults/main.yml` | OIDC issuer and external URL variables |
| `ansible/roles/zot/templates/oidc-credentials.json.j2` | OIDC client credentials |
| `.dagger/src/blumeops_ci/main.py` | `publish()` with registry auth |
| `.forgejo/workflows/build-container.yaml` | Dagger push with API key |
| `.forgejo/workflows/build-container-nix.yaml` | Skopeo push with API key |

## Verified

- [x] Anonymous pull works (pull-through cache on gilbert)
- [x] Unauthenticated push fails (401)
- [x] OIDC browser login works (redirect to Authentik and back)
- [x] API key push works (zot-ci API key)
- [x] CI push succeeds (Dagger and Nix/skopeo paths)
- [x] Pull-through caching still works
- [x] Metrics endpoint accessible without auth
- [x] `mise run services-check` passes

## Related

- [[register-zot-oidc-client]] — OIDC client registration in Authentik
- [[wire-ci-registry-auth]] — CI push path wiring
- [[enforce-tag-immutability]] — Server-side via accessControl
- [[adopt-commit-based-container-tags]] — Commit-SHA-based image tags
