---
title: External Secrets
modified: 2026-03-23
last-reviewed: 2026-03-23
tags:
  - kubernetes
  - secrets
---

# External Secrets

The [External Secrets Operator](https://external-secrets.io/) syncs secrets from 1Password into Kubernetes Secrets. It runs in the `1password-connect` namespace alongside the 1Password Connect server.

## How It Works

Each service that needs secrets defines an `ExternalSecret` resource referencing a 1Password item and field. The operator polls 1Password Connect and creates/updates native Kubernetes Secrets.

## Manifests

- **Operator + Connect server:** `argocd/manifests/1password-connect/`
- **Per-service ExternalSecrets:** in each service's manifest directory (e.g., `argocd/manifests/grafana-config/external-secret-*.yaml`)

## Related

- [[1password]] - Credential management
- [[security-model]] - Secrets flow architecture
