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

The `ci-zot` service account (created in [[register-zot-oidc-client]]) belongs to
the `ci-artifacts` group — `["read", "create"]`, so CI can push new tags
but not overwrite or delete. It authenticates with a zot API key generated after
the account's first OIDC login.

`.forgejo/workflows/build-container.yaml` builds `containers/<name>/default.nix`
with `nix-build` on the `nix-container-builder` runner, then pushes with
`skopeo copy --dest-creds=ci-zot:$CI_ZOT_API_KEY`. The push leg runs only on
push to main — PR runs build but never see the key (fork runs carry no
secrets).

## Secret flow

The key's master copy lives in 1Password (`Forgejo Secrets` item, field
`ci-zot-api`, blumeops vault). CI consumes the `blumeops-ci/ci-zot` item
(field `api-key`) at job time — workflows `op read` it with
`BLUMEOPS_CI_OP_TOKEN` ([[blumeops-ci-item-migration]]). `mise run
zot-apikey-rotate ci-zot` updates both copies (the CI-vault edit takes effect
on the next run, no provisioning needed). The key expires every 90 days — see
[[zot#API Key Rotation]].

## Related

- [[harden-zot-registry]] — Parent: registry auth + access control
- [[register-zot-oidc-client]] — OIDC client + service account
- [[container-versioning]] — Build/tag scheme
