---
title: Wire CI Registry Auth
modified: 2026-06-17
tags:
  - how-to
  - zot
  - ci
  - forgejo
---

# Wire CI Registry Auth

How CI pipelines authenticate to the zot registry after OIDC + apikey auth is enabled.

## Overview

The `zot-ci` service account (created in [[register-zot-oidc-client]]) belongs to the `artifact-workloads` group, granting `["read", "create"]` permissions — CI can push new tags but cannot overwrite or delete existing ones.

Authentication uses a zot API key generated after the service account's first OIDC login. The key is stored in 1Password (`Forgejo Secrets` item, field `zot-ci-api`, in blumeops vault) and synced to Forgejo Actions secrets via the `forgejo_actions_secrets` ansible role. The key expires every 90 days — see [[zot#API Key Rotation]] for the rotation procedure.

## Push Path

`.forgejo/workflows/build-container.yaml` builds `containers/<name>/default.nix`
with `nix-build` on the `nix-container-builder` runner, then passes
`--dest-creds=zot-ci:$ZOT_CI_API_KEY` to `skopeo copy` to push the image.

(Until [[retire-minikube]] a parallel Dagger path pushed Dockerfile/`container.py`
containers via the `publish()` function and `with_registry_auth()`; that path —
and its workflow — were retired when the build went nix-only.)

## Secret Flow

1Password `Forgejo Secrets` item (field `zot-ci-api`) → ansible pre_task fetches it → `forgejo_actions_secrets` role syncs to Forgejo API → the `nix-container-builder` runner (ringtail) accesses it as `${{ secrets.ZOT_CI_API_KEY }}`.

## Key Files

| File | Purpose |
|------|---------|
| `.forgejo/workflows/build-container.yaml` | Passes API key to `skopeo copy` |
| `ansible/roles/forgejo_actions_secrets/` | Syncs the key to Forgejo Actions secrets |
| `ansible/playbooks/indri.yml` | Pre_task fetches API key from 1Password |
| `ansible/roles/forgejo_actions_secrets/defaults/main.yml` | Secret entry for `ZOT_CI_API_KEY` |

## Related

- [[harden-zot-registry]] — Parent goal
- [[register-zot-oidc-client]] — OIDC client registration
