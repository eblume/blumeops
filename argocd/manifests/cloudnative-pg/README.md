# CloudNativePG Operator

Kubernetes operator for managing PostgreSQL clusters with high availability.

## Source

- Helm chart: `cloudnative-pg` from https://cloudnative-pg.github.io/charts
- Documentation: https://cloudnative-pg.io/documentation/

## Deployment

Managed via ArgoCD Application using Helm source (not kustomize).
The Application points directly to the upstream Helm repository.

## ArgoCD CLI Commands

```bash
# Check application status
argocd app get cloudnative-pg

# Trigger a sync
argocd app sync cloudnative-pg

# View deployment history
argocd app history cloudnative-pg
```

## Verification

```bash
# Check operator pod is running
kubectl get pods -n cnpg-system

# Check operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg

# Check CRDs are installed
kubectl get crd | grep cnpg
```

## Files

| File | Description |
|------|-------------|
| `values.yaml` | Helm values for customization |
| `README.md` | This file |

## Notes

- The operator is deployed to `cnpg-system` namespace
- PostgreSQL clusters are created separately using the `Cluster` CRD (see Step 7)
- No secrets required for the operator itself
