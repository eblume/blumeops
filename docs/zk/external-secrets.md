---
id: external-secrets
aliases:
  - external-secrets
  - eso
  - external-secrets-operator
tags:
  - blumeops
---

# External Secrets Operator

External Secrets Operator (ESO) syncs secrets from 1Password to Kubernetes Secrets via 1Password Connect.

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

## Usage

ClusterSecretStore `onepassword-blumeops` provides access to the blumeops vault. See `argocd/manifests/devpi/external-secret.yaml` for a simple example.

**Important:** 1Password Connect doesn't support the `?ssh-format=openssh` query parameter. SSH keys must be stored as Secure Notes with the OpenSSH-formatted key (see `argocd-forge-ssh-key` item).

```bash
# Check all ExternalSecrets
kubectl --context=minikube-indri get externalsecret -A

# Find 1Password field names
op item get <item> --vault blumeops --format json | jq '.fields[] | .label'
```

## Bootstrap (One-Time Setup)

If reinstalling from scratch:

1. Create Connect server credentials:
   ```bash
   op connect server create blumeops --vaults blumeops
   op connect token create blumeops --server <server-id> --vault blumeops
   ```

2. Store in 1Password item "1Password Connect":
   - `credentials-file`: raw JSON
   - `credentials-base64`: base64-encoded JSON
   - `token`: access token

3. Apply bootstrap secret:
   ```bash
   kubectl --context=minikube-indri create namespace 1password
   op inject -i argocd/manifests/1password-connect/secret-credentials.yaml.tpl | \
     kubectl --context=minikube-indri apply -f -
   ```

4. Sync apps in order:
   - `argocd app sync 1password-connect`
   - `argocd app sync external-secrets-crds`
   - `argocd app sync external-secrets`
   - `argocd app sync external-secrets-config`

## Related

- [[1767747119-YCPO|BlumeOps]]
- [[argocd|ArgoCD]]
