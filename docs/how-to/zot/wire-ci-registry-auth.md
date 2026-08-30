---
title: Wire CI Registry Auth
modified: 2026-06-18
last-reviewed: 2026-08-30
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

The key's master copy lives in 1Password (`Forgejo Secrets` item, field
`zot-ci-api`, blumeops vault). CI consumes the `blumeops-ci/zot-ci` item
(field `api-key`) at job time — workflows `op read` it with
`BLUMEOPS_CI_OP_TOKEN` ([[blumeops-ci-item-migration]]); talos and horkos
release CI read the same item. On rotation update both copies (the
`op item edit` in the CI vault takes effect on the next run, no
provisioning needed). The key expires every 90 days — see
[[zot#API Key Rotation]].

## Related

- [[harden-zot-registry]] — Parent: registry auth + access control
- [[register-zot-oidc-client]] — OIDC client + service account
- [[container-versioning]] — Build/tag scheme
