# ArgoCD

GitOps continuous delivery for Kubernetes, with self-management via ArgoCD.

## Prerequisites

- Tailscale operator deployed (see `argocd/manifests/tailscale-operator/README.md`)
- SSH key added to Forgejo user for access to all forge repos (not a deploy key)

## Manual Bootstrap

Bootstrap is required when setting up a new cluster. After bootstrap, ArgoCD manages itself.

```bash
# 1. Create namespace
kubectl create namespace argocd

# 2. Apply ArgoCD manifests via kustomize
kubectl apply -k argocd/manifests/argocd/

# 3. Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 4. Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# 5. Login and change password
argocd login argocd.tail8d86e.ts.net --username admin --grpc-web
argocd account update-password

# 6. Apply repo-creds-forge credential template for SSH access to all forge repos
PRIV_KEY=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key?ssh-format=openssh")$'\n' && \
kubectl create secret generic repo-creds-forge -n argocd \
  --from-literal=type=git \
  --from-literal=url='ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/' \
  --from-literal=insecure=true \
  --from-literal=sshPrivateKey="$PRIV_KEY" && \
kubectl label secret repo-creds-forge -n argocd argocd.argoproj.io/secret-type=repo-creds

# 7. Apply ArgoCD Applications (self-management + app-of-apps)
kubectl apply -f argocd/apps/argocd.yaml
kubectl apply -f argocd/apps/apps.yaml
```

After step 7, ArgoCD manages itself and all applications defined in `argocd/apps/`.

## Access

- URL: https://argocd.tail8d86e.ts.net
- Username: `admin`
- Password: Stored in 1Password after initial setup

## ArgoCD CLI Commands

```bash
# Check all applications
argocd app list

# Sync a specific application
argocd app sync <app-name>

# Check application status
argocd app get <app-name>

# Hard refresh (clear git cache)
argocd app get <app-name> --hard-refresh
```

## Adding New Applications

1. Create an Application manifest in `argocd/apps/<app-name>.yaml`
2. Commit and push to forge
3. ArgoCD (via app-of-apps) automatically picks it up

Example Application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | References upstream install.yaml + local customizations |
| `service-tailscale.yaml` | Tailscale Ingress for external access with Let's Encrypt TLS |
| `argocd-cmd-params-cm.yaml` | Patch to disable HTTPS redirect (TLS terminates at Ingress) |
| `repo-forge-secret.yaml.tpl` | Template for forge SSH credential template (manual) |
| `README.md` | This file |

## Notes

- **TODO:** Secrets (`repo-creds-forge`) are not managed by ArgoCD and must be applied manually.
  Future improvement: integrate with a secrets operator (e.g., External Secrets).
- The credential template (`repo-creds`) uses a URL prefix to match all repos under `eblume/`.
- ArgoCD uses Tailscale Ingress with Let's Encrypt for TLS termination.
- The `--grpc-web` flag is required for CLI access through the Tailscale ingress.
