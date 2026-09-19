---
title: External Secrets
modified: 2026-09-19
last-reviewed: 2026-09-19
tags:
  - kubernetes
  - secrets
---

# External Secrets

The [External Secrets Operator](https://external-secrets.io/) syncs secrets from 1Password into Kubernetes Secrets. It runs in the `external-secrets` namespace on ringtail's k3s cluster, with the 1Password Connect server in its own namespace.

## How It Works

Each service that needs secrets defines an `ExternalSecret` resource referencing a 1Password item and field. The operator polls 1Password Connect and creates/updates native Kubernetes Secrets.

## Manifests

- **Operator:** `argocd/manifests/external-secrets/` (base) with the `argocd/manifests/external-secrets-ringtail/` overlay; the image tag is pinned in the kustomizations.
- **CRDs:** from the forge mirror's `helm-chart-X.Y.Z` tag via the manually-synced app `argocd/apps/external-secrets-crds-ringtail.yaml` (synced before the operator).
- **1Password Connect server:** `argocd/manifests/1password-connect/`
- **Per-service ExternalSecrets:** in each service's manifest directory (e.g., `argocd/manifests/grafana-config/external-secret-*.yaml`)

## Related

- [[1password]] - Credential management
- [[security-model]] - Secrets flow architecture
- [[external-secrets-operator|External Secrets Operator]] - service/deployment doc in `docs/reference/services/`
