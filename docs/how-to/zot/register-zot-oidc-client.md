---
title: Register Zot OIDC Client
modified: 2026-08-22
last-reviewed: 2026-08-22
tags:
  - how-to
  - zot
  - authentik
  - oidc
---

# Register Zot OIDC Client

Zot's OAuth2 provider and application are registered in Authentik via blueprint,
following the same pattern as Grafana and Forgejo.

The `zot.yaml` section of `argocd/manifests/authentik/configmap-blueprint.yaml`
defines an OAuth2Provider (`client_id: zot`), an Application, PolicyBindings
to the `admins` group and the `artifact-workloads` group, and a `zot-ci`
service account belonging to `artifact-workloads`.

The client secret is stored in 1Password as field `zot-client-secret` on the
"Authentik (blumeops)" item (referenced by item ID `oor7os5kapczgpbwv7obkca4y4`
to dodge the parentheses in `op read`). An ExternalSecret wires it into the
Authentik worker Deployment as `AUTHENTIK_ZOT_CLIENT_SECRET`, which the blueprint
consumes via `!Env`. On indri, the zot role renders `oidc-credentials.json.j2`
(guarded by a `when`), with the secret fetched in an `indri.yml` pre_task.

The `zot-ci` service-account password and its API keys are manual post-deploy
steps — not automated in the blueprint.

## Related

- [[harden-zot-registry]] — Parent goal
- [[wire-ci-registry-auth]] — How CI uses the `zot-ci` service account
- [[deploy-authentik]] — Authentik deployment
