---
title: Register Zot OIDC Client
modified: 2026-02-21
tags:
  - how-to
  - zot
  - authentik
  - oidc
---

# Register Zot OIDC Client

Register a zot OAuth2 provider and application in Authentik via blueprint, following the same pattern as Grafana and Forgejo.

Completed in PR [#236](https://forge.ops.eblu.me/eblume/blumeops/pulls/236).

## What Was Done

1. **Added `zot.yaml` blueprint section** to `argocd/manifests/authentik/configmap-blueprint.yaml`:
   - OAuth2Provider (`client_id: zot`), Application, PolicyBinding (admins group), `artifact-workloads` group, and `zot-ci` service account
2. **Client secret** stored in 1Password as field `zot-client-secret` on the "Authentik (blumeops)" item (referenced by item ID `oor7os5kapczgpbwv7obkca4y4` to avoid parentheses in `op read`)
3. **ExternalSecret** wired `zot-client-secret` → worker Deployment env var `AUTHENTIK_ZOT_CLIENT_SECRET` → blueprint `!Env`
4. **OIDC credentials template** (`ansible/roles/zot/templates/oidc-credentials.json.j2`) deployed by zot role with a `when` guard; pre_task in `ansible/playbooks/indri.yml` fetches the secret from 1Password

### Deviations from Original Plan

- Worker Deployment env var injection was an additional wiring step not originally listed
- Service account password and API keys are manual post-deploy steps (not automated in the blueprint)

## Key Files

| File | Purpose |
|------|---------|
| `argocd/manifests/authentik/configmap-blueprint.yaml` | Zot blueprint (provider + app + policy + group + service account) |
| `argocd/manifests/authentik/external-secret.yaml` | `AUTHENTIK_ZOT_CLIENT_SECRET` env var |
| `argocd/manifests/authentik/deployment-worker.yaml` | Env var injection for blueprint `!Env` |
| `ansible/roles/zot/templates/oidc-credentials.json.j2` | OIDC credentials for zot |
| `ansible/playbooks/indri.yml` | Pre_task for zot OIDC client secret |

## Related

- [[harden-zot-registry]] — Parent goal
- [[deploy-authentik]] — Authentik deployment (completed)
