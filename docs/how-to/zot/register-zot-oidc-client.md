---
title: Register Zot OIDC Client
modified: 2026-10-22
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
defines an OAuth2Provider (`client_id: zot`) and an Application. The
PolicyBindings to the `admins` group and the artifact/CI groups, and the
service accounts `ci-zot` (group `ci-artifacts`), `ci-zot-talos`,
`ci-zot-horkos`, and `horkos-zot` are defined in
`argocd/manifests/authentik/principals.yaml` (rendered into the blueprint
ConfigMap; [[manage-authentik-principals]]).

The client secret is stored in 1Password as field `zot-client-secret` on the
"Authentik (blumeops)" item (referenced by item ID `oor7os5kapczgpbwv7obkca4y4`
to dodge the parentheses in `op read`). An ExternalSecret wires it into the
Authentik worker Deployment as `AUTHENTIK_ZOT_CLIENT_SECRET`, which the blueprint
consumes via `!Env`. On indri, the seed-secrets manifest entry in `darwin/indri/secrets.json` seats `~/.config/zot/oidc-credentials.json` from the same vault field (kind `op`; the entry's `format` wraps the value in the JSON shape zot reads, restart `mcquack.eblume.zot`), and the switch's checks slot refuses a missing file (V5-83 link 2, eblume/blumeops#1782).

API keys are bootstrapped and rotated via `mise run zot-apikey-rotate
<identity>` (see [[wire-ci-registry-auth]] and the [[zot]] API Key Rotation
section); only the first key of an identity is a manual browser step.

## Related

- [[harden-zot-registry]] — Parent goal
- [[wire-ci-registry-auth]] — How CI uses the `ci-zot` service account
- [[authentik]] — Authentik reference
