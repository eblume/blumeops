# External Secrets Operator

External Secrets Operator (ESO) syncs secrets from 1Password Connect to native Kubernetes Secrets.

## Architecture

- **ClusterSecretStore** (`onepassword-blumeops`): Cluster-wide access to 1Password via Connect
- **ExternalSecret** (per-namespace): Defines which secrets to sync from 1Password

## Prerequisites

1Password Connect must be deployed and healthy before syncing ESO.

## Deployment

```bash
argocd app sync external-secrets
```

## Verification

```bash
# Check operator pods
kubectl --context=minikube-indri -n external-secrets get pods

# Check ClusterSecretStore status
kubectl --context=minikube-indri get clustersecretstore onepassword-blumeops

# Check all ExternalSecrets across namespaces
kubectl --context=minikube-indri get externalsecret -A
```

## Creating ExternalSecrets

To sync a secret from 1Password, create an ExternalSecret in the target namespace:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword-blumeops
  target:
    name: my-secret           # Name of K8s Secret to create
    creationPolicy: Owner     # ESO owns and manages the Secret
  data:
  - secretKey: password       # Key in the K8s Secret
    remoteRef:
      key: My 1Password Item  # Title of item in 1Password
      property: password      # Field label in 1Password item
```

### Finding 1Password Item Details

```bash
# List items in blumeops vault
op item list --vault blumeops

# Get field names for an item
op item get <item-id> --vault blumeops --format json | jq -r '.fields[] | .label'
```

## Troubleshooting

### ClusterSecretStore not ready
- Check 1Password Connect is running: `kubectl --context=minikube-indri -n 1password get pods`
- Verify token secret exists: `kubectl --context=minikube-indri -n 1password get secret onepassword-token`

### ExternalSecret not syncing
- Check the ExternalSecret status: `kubectl --context=minikube-indri describe externalsecret <name> -n <namespace>`
- Verify the 1Password item title and field names match exactly
- Check ESO controller logs: `kubectl --context=minikube-indri -n external-secrets logs -l app.kubernetes.io/name=external-secrets`

## Related

- [External Secrets Operator Docs](https://external-secrets.io/)
- [1Password Provider](https://external-secrets.io/latest/provider/1password-automation/)
- [1Password Connect](../1password-connect/README.md)
