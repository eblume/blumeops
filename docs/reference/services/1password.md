---
title: 1Password
date-modified: 2026-02-10
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

## Disaster Recovery Backup

The `mise run op-backup` task encrypts a `.1pux` vault export and transfers it to [[indri]] for inclusion in [[borgmatic]] backups. See [[restore-1password-backup]] for the full recovery procedure.

## Related

- [[argocd]] - Uses secrets for git access
- [[postgresql]] - Database credentials
- [[restore-1password-backup]] - Recovery from backup
- [[borgmatic]] - Backup system
