# Tailscale Kubernetes Operator

Manifests for the Tailscale Kubernetes Operator, managed via ArgoCD.

## Source

- `operator.yaml` - Static manifest from https://github.com/tailscale/tailscale/tree/main/cmd/k8s-operator/deploy/manifests
- Secret block removed from `operator.yaml` - managed separately via `secret.yaml.tpl`
- Image reference changed to fully-qualified `docker.io/tailscale/k8s-operator:stable`

## Prerequisites

1. OAuth client in Tailscale admin console with:
   - Devices: Core (Read & Write) - tag: `tag:k8s-operator`
   - Auth Keys: Read & Write
   - Services: Write
2. ACL with `tag:k8s-operator` owning `tag:k8s` (so operator can tag resources it creates)

## Manual Bootstrap (Before ArgoCD)

Tailscale operator must be deployed before ArgoCD since ArgoCD uses Tailscale for ingress.

```bash
# 1. Create namespace
kubectl create namespace tailscale

# 2. Apply OAuth secret (uses 1Password)
op inject -i argocd/manifests/tailscale-operator/secret.yaml.tpl | kubectl apply -f -

# 3. Apply manifests via kustomize
kubectl apply -k argocd/manifests/tailscale-operator/
```

## Ongoing Management (After ArgoCD)

Once ArgoCD is running, the operator is managed by the `tailscale-operator` ArgoCD Application.
ArgoCD pulls manifests from forge and applies them automatically.

## ArgoCD CLI Commands

```bash
# Check application status
argocd app get tailscale-operator

# Trigger a sync (pull latest from forge and apply)
argocd app sync tailscale-operator

# Preview what would change without applying
argocd app diff tailscale-operator

# View deployment history
argocd app history tailscale-operator

# Hard refresh (clear cache and re-fetch from git)
argocd app get tailscale-operator --hard-refresh
```

## Verification

```bash
# Check operator pod is running
kubectl get pods -n tailscale

# Check operator logs
kubectl logs -n tailscale -l app.kubernetes.io/name=operator
```

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Kustomize configuration for all manifests |
| `operator.yaml` | Operator deployment, CRDs, RBAC (secret removed) |
| `proxyclass.yaml` | ProxyClass with fully-qualified images |
| `dnsconfig.yaml` | DNSConfig for cluster-to-tailnet name resolution |
| `egress-forge.yaml` | Egress proxy for accessing forge on indri |
| `secret.yaml.tpl` | 1Password template for OAuth credentials (manual) |
| `README.md` | This file |

## Notes

- **TODO:** The OAuth secret (`operator-oauth`) is not managed by ArgoCD and must be applied
  manually. Future improvement: integrate with a secrets operator (e.g., External Secrets).
- Services using the Tailscale LoadBalancer should reference the ProxyClass:
  ```yaml
  annotations:
    tailscale.com/proxy-class: "default"
  ```
- The egress proxy for forge is **deprecated**. Forge is now accessible via Caddy at
  `forge.ops.eblu.me` (HTTPS) and `forge.ops.eblu.me:2222` (SSH), which pods can reach directly.
