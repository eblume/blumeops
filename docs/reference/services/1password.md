---
title: 1Password
tags:
  - service
  - secrets
---

# 1Password

Root credential store for all BlumeOps secrets, synced to Kubernetes via External Secrets Operator.

## Architecture

```
1Password Cloud
      |
      v
1Password Connect (namespace: 1password)
      |
      v
External Secrets Operator (namespace: external-secrets)
      |
      v
Native Kubernetes Secrets
```

## Vault

The `blumeops` vault contains all infrastructure credentials.

## Kubernetes Integration

**ClusterSecretStore:** `onepassword-blumeops`

Services reference 1Password items via `ExternalSecret` manifests.

## Related

- [[services/argocd|ArgoCD]] - Uses secrets for git access
- [[services/postgresql|PostgreSQL]] - Database credentials
