# CloudNativePG Operator

Kubernetes operator for managing PostgreSQL clusters with high availability.

## Source

- Upstream mirror: `mirrors/cloudnative-pg` on forge (from https://github.com/cloudnative-pg/cloudnative-pg)
- Documentation: https://cloudnative-pg.io/documentation/

## Deployment

Managed via ArgoCD Application pointing directly at the upstream release
manifest in the forge-mirrored repo. No Helm chart or vendored manifests —
ArgoCD applies the release YAML from the `releases/` directory using a
`directory.include` filter.

## Upgrading

To upgrade the operator, edit `argocd/apps/cloudnative-pg.yaml`:

1. Update `targetRevision` to the new tag (e.g. `v1.28.0`)
2. Update `directory.include` to match (e.g. `cnpg-1.28.0.yaml`)
3. Commit and sync via ArgoCD

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
kubectl get pods -n cnpg-system --context=minikube-indri

# Check operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --context=minikube-indri

# Check CRDs are installed
kubectl get crd --context=minikube-indri | grep cnpg
```

## Files

| File | Description |
|------|-------------|
| `README.md` | This file |

## Notes

- The operator is deployed to `cnpg-system` namespace
- PostgreSQL clusters are created separately using the `Cluster` CRD
- No secrets required for the operator itself
- `ServerSideApply=true` is required for the large CRDs
- The `values.yaml` was removed — no Helm customization was in use
