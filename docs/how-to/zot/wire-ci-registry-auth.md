---
title: Wire CI Registry Auth
modified: 2026-06-18
tags:
  - how-to
  - zot
  - ci
  - forgejo
---

# Wire CI Registry Auth

How CI authenticates to the [[zot]] registry to push container images.

The `zot-ci` service account (created in [[register-zot-oidc-client]]) belongs to
the `artifact-workloads` group — `["read", "create"]`, so CI can push new tags
but not overwrite or delete. It authenticates with a zot API key generated after
the account's first OIDC login.

`.forgejo/workflows/build-container.yaml` builds `containers/<name>/default.nix`
with `nix-build` on the `nix-container-builder` runner, then pushes with
`skopeo copy --dest-creds=zot-ci:$ZOT_CI_API_KEY`.

## Secret flow

The key lives in 1Password (`Forgejo Secrets` item, field `zot-ci-api`, blumeops
vault). A pre_task in `ansible/playbooks/indri.yml` fetches it; the
`forgejo_actions_secrets` role syncs it to Forgejo Actions secrets; the runner
reads it as `${{ secrets.ZOT_CI_API_KEY }}`. The key expires every 90 days — see
[[zot#API Key Rotation]].

## Related

- [[harden-zot-registry]] — Parent: registry auth + access control
- [[register-zot-oidc-client]] — OIDC client + service account
- [[container-versioning]] — Build/tag scheme
