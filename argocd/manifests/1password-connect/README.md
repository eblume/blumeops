# 1Password Connect

1Password Connect provides REST API access to 1Password vault items for External Secrets Operator.

## Architecture

```
1Password Cloud
      |
      v
1Password Connect (this service)
      |
      v
External Secrets Operator
      |
      v
Native Kubernetes Secrets
```

## Prerequisites (One-Time Setup)

Run these steps on the workstation (gilbert) before deploying:

### 1. Create Connect Server Credentials

```bash
# This creates the credentials file and outputs a server ID
op connect server create blumeops --vaults blumeops

# Save the 1password-credentials.json file contents
```

### 2. Create Access Token

```bash
# Replace <server-id> with the ID from step 1
op connect token create blumeops --server <server-id> --vault blumeops

# Save the token
```

### 3. Store Credentials in 1Password

Create a new item "1Password Connect" in the blumeops vault with:
- `credentials-file` field: Paste the contents of `1password-credentials.json` (NOT base64 encoded)
- `token` field: Paste the access token

### 4. Create Bootstrap Secret

```bash
kubectl --context=minikube-indri create namespace 1password
op inject -i argocd/manifests/1password-connect/secret-credentials.yaml.tpl | \
  kubectl --context=minikube-indri apply -f -
```

## Deployment

```bash
argocd app sync apps
argocd app sync 1password-connect
```

## Verification

```bash
# Check pods are running
kubectl --context=minikube-indri -n 1password get pods

# Check logs
kubectl --context=minikube-indri -n 1password logs -l app=onepassword-connect

# Test API health (port-forward first)
kubectl --context=minikube-indri -n 1password port-forward svc/onepassword-connect 8080:8080 &
curl http://localhost:8080/health
```

## Troubleshooting

### Pods not starting
- Check the bootstrap secret exists: `kubectl --context=minikube-indri -n 1password get secret op-credentials`
- Verify credentials format in 1Password item

### API returning 401
- Check the token secret: `kubectl --context=minikube-indri -n 1password get secret onepassword-token`
- Verify the token has access to the blumeops vault

## Related

- [1Password Connect Documentation](https://developer.1password.com/docs/connect/)
- [External Secrets Operator](../external-secrets/README.md)
