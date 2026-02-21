---
title: Wire CI Registry Auth
modified: 2026-02-20
status: active
tags:
  - how-to
  - zot
  - ci
  - forgejo
---

# Wire CI Registry Auth

Ensure both CI push paths authenticate to zot after auth is enabled.

## Context

There are two push paths to update:

1. **Dagger path** (`.forgejo/workflows/build-container.yaml` → `.dagger/src/blumeops_ci/main.py`): Add `with_registry_auth()` to the Dagger `publish()` call, sourcing the API key from env var `ZOT_CI_API_KEY`.

2. **Nix/skopeo path** (`.forgejo/workflows/build-container-nix.yaml`): Add `--dest-creds` to `skopeo copy`, sourcing the API key from the same env var.

> **Note:** The API key must be generated manually after OIDC login is working — log in to zot UI via browser, generate an API key, and store it in 1Password. This is a manual step between [[register-zot-oidc-client]] and this card, but not modeled as a formal `requires` dependency.

## Secret Flow

### Indri runner (minikube)

1Password item (new: `zot-ci-apikey`) → ExternalSecret in `forgejo-runner` namespace → env var `ZOT_CI_API_KEY` in runner pod

### Ringtail runner (k3s)

1Password → `/etc/forgejo-runner/zot-api-key.env` (or similar) deployed by NixOS config

## Key Files

| File | Purpose |
|------|---------|
| `.dagger/src/blumeops_ci/main.py` | Add `with_registry_auth()` to publish |
| `.forgejo/workflows/build-container.yaml` | Pass `ZOT_CI_API_KEY` to Dagger |
| `.forgejo/workflows/build-container-nix.yaml` | Add `--dest-creds` to skopeo |
| `argocd/manifests/forgejo-runner/deployment.yaml` | Mount secret as env var |
| `argocd/manifests/forgejo-runner/external-secret.yaml` | Pull API key from 1Password |
| `nixos/ringtail/configuration.nix` | Ringtail runner secret provisioning |

## Verification

- [ ] Dagger push succeeds with registry auth
- [ ] Nix/skopeo push succeeds with registry auth
- [ ] Push without credentials fails (401)

## Related

- [[harden-zot-registry]] — Parent goal
- [[register-zot-oidc-client]] — OIDC client registration (do first)
