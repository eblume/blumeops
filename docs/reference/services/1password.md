---
title: 1Password
modified: 2026-05-22
last-reviewed: 2026-05-22
tags:
  - service
  - secrets
---

# 1Password

Root credential store for all BlumeOps secrets. Kubernetes workloads read items via [[external-secrets|External Secrets Operator]]; humans and agents read via the `op` CLI.

## Vaults

| Vault | Purpose |
|-------|---------|
| `blumeops` | Infrastructure secrets — referenced by ExternalSecret manifests and scripts. |
| `Personal` | Human login credentials keyed by URL for autofill. Not consumed by infrastructure. |

## Kubernetes Integration

```
1Password Cloud
      |
      v
1Password Connect (namespace: 1password, deployed on both indri and ringtail)
      |
      v
External Secrets Operator (namespace: external-secrets)
      |
      v
Native Kubernetes Secrets
```

**ClusterSecretStore:** `onepassword-blumeops` (same name on both clusters).

Services reference 1Password items via `ExternalSecret` manifests. The `k3s-ringtail` cluster runs a `onepassword-connect` deployment (`1password-connect-ringtail` app) talking to the vault.

## Direct Access

Prefer `op read "op://vault/item/field"` over `op item get --fields` in scripts and IaC — `op item get --fields` wraps multi-line values in quotes, corrupting them. `op item get` without flags is fine for exploring item metadata.

If an item name contains special characters (e.g. parentheses), use the item ID instead of the name in the `op://` path.

## Disaster Recovery Backup

The `mise run op-backup` task encrypts a `.1pux` vault export and transfers it to [[indri]] for inclusion in [[borgmatic]] backups. See [[run-1password-backup]] for the step-by-step procedure and [[restore-1password-backup]] for disaster recovery.

## Related

- [[external-secrets]] — Kubernetes operator that consumes ClusterSecretStore
- [[argocd]] — Uses secrets for git access
- [[postgresql]] — Database credentials
- [[run-1password-backup]] — Periodic backup procedure
- [[restore-1password-backup]] — Recovery from backup
- [[borgmatic]] — Backup system
