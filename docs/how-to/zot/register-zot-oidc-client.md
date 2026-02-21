---
title: Register Zot OIDC Client
modified: 2026-02-21
status: active
tags:
  - how-to
  - zot
  - authentik
  - oidc
---

# Register Zot OIDC Client

Register a zot OAuth2 provider and application in Authentik via blueprint, following the same pattern as Grafana and Forgejo.

## What to Do

1. **Add `zot.yaml` blueprint section** to `argocd/manifests/authentik/configmap-blueprint.yaml`:
   - OAuth2Provider: `client_id: zot`, redirect URI `https://registry.ops.eblu.me/zot/auth/callback/oidc`
   - Application linked to the provider
   - PolicyBinding restricting access to the admins group

2. **Generate and store client secret** in 1Password item "Authentik (blumeops)" as field `zot-client-secret`

3. **Add `AUTHENTIK_ZOT_CLIENT_SECRET`** to Authentik worker's ExternalSecret at `argocd/manifests/authentik/external-secret.yaml`

4. **Blueprint references the secret** via `!Env AUTHENTIK_ZOT_CLIENT_SECRET`

5. **Create OIDC credentials file** for zot's Ansible role:
   - New template `ansible/roles/zot/templates/oidc-credentials.json.j2` containing `client_id` and `client_secret`
   - Source `client_secret` from 1Password via a new pre_task in `ansible/playbooks/indri.yml`

6. **Create `artifact-workloads` group** in Authentik blueprint:
   - Add a group resource to the blueprint with name `artifact-workloads`
   - Create a service account user in the `artifact-workloads` group for CI push operations
   - This group gets `["read", "create"]` in zot's `accessControl` (no update/delete — enforces tag immutability)

## Key Files

| File | Purpose |
|------|---------|
| `argocd/manifests/authentik/configmap-blueprint.yaml` | Add zot blueprint (provider + app + policy + group) |
| `argocd/manifests/authentik/external-secret.yaml` | Add `AUTHENTIK_ZOT_CLIENT_SECRET` env var |
| `ansible/roles/zot/templates/oidc-credentials.json.j2` | New: OIDC credentials for zot |
| `ansible/playbooks/indri.yml` | New pre_task for zot OIDC client secret |

## Verification

- [ ] Authentik admin UI shows zot application
- [ ] OIDC discovery endpoint includes zot client
- [ ] Blueprint status is `successful` (check via API, not just logs)
- [ ] `artifact-workloads` group exists with CI service account

## Related

- [[harden-zot-registry]] — Parent goal
- [[deploy-authentik]] — Authentik deployment (completed)
