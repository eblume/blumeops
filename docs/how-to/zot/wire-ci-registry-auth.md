---
title: Wire CI Registry Auth
modified: 2026-02-21
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

## Push Paths

### Dagger path (Dockerfile containers)

`.forgejo/workflows/build-container.yaml` passes `--registry-password=env:ZOT_CI_API_KEY` to the Dagger `publish()` function, which calls `with_registry_auth()` before pushing.

### Nix/skopeo path (Nix containers)

`.forgejo/workflows/build-container-nix.yaml` passes `--dest-creds=zot-ci:$ZOT_CI_API_KEY` to `skopeo copy`.

## Secret Flow

1Password `Forgejo Secrets` item (field `zot-ci-api`) → ansible pre_task fetches it → `forgejo_actions_secrets` role syncs to Forgejo API → both runners (k8s on indri, host on ringtail) access it as `${{ secrets.ZOT_CI_API_KEY }}`.

## Key Files

| File | Purpose |
|------|---------|
| `.dagger/src/blumeops_ci/main.py` | `publish()` accepts optional `registry_password` |
| `.forgejo/workflows/build-container.yaml` | Passes API key to Dagger |
| `.forgejo/workflows/build-container-nix.yaml` | Passes API key to skopeo |
| `ansible/playbooks/indri.yml` | Pre_task fetches API key from 1Password |
| `ansible/roles/forgejo_actions_secrets/defaults/main.yml` | Secret entry for `ZOT_CI_API_KEY` |

## Related

- [[harden-zot-registry]] — Parent goal
- [[register-zot-oidc-client]] — OIDC client registration
