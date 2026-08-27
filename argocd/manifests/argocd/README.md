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
argocd login argocd.tail8d86e.ts.net --username admin
argocd account update-password

# 6. Apply the repo-creds credential templates for SSH access to all forge repos.
#    Two entries, one per spelling of the same host: the mirrors/* repos use
#    forge.ops.eblu.me, while everything tracking eblume/blumeops uses
#    forge.eblu.me so ArgoCD's push webhook can match it (see
#    docs/reference/services/argocd.md). ArgoCD picks creds by longest URL
#    prefix. The forge.eblu.me spelling only resolves in-cluster because of the
#    CoreDNS rewrite that ships with the node in
#    nixos/ringtail/configuration.nix — if git fetches fail here with a DNS or
#    connection-refused error, that manifest did not land.
PRIV_KEY=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key?ssh-format=openssh")$'\n' && \
HOST_KEY=$(ssh-keyscan -p 2222 forge.ops.eblu.me 2>/dev/null | grep ssh-rsa | cut -d' ' -f2-) && \
for spelling in ops.eblu.me:forge eblu.me:forge-alias; do
  host="forge.${spelling%%:*}"; name="repo-creds-${spelling##*:}"
  kubectl create secret generic "$name" -n argocd \
    --from-literal=type=git \
    --from-literal=url="ssh://forgejo@${host}:2222/" \
    --from-literal=insecure=false \
    --from-literal=sshPrivateKey="$PRIV_KEY" \
    --from-literal=sshKnownHosts="[${host}]:2222 $HOST_KEY" && \
  kubectl label secret "$name" -n argocd argocd.argoproj.io/secret-type=repo-creds
done

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
2. Merge to `main`
3. `argocd app sync apps` — the app-of-apps is manual on purpose, so a new
   Application never appears unattended

Once it exists, the app syncs itself on every subsequent merge. See
[the ArgoCD reference](../../../docs/reference/services/argocd.md) for the full
sync policy and the four applications deliberately left manual.

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
    repoURL: ssh://forgejo@forge.eblu.me:2222/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

## Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | References upstream install.yaml + local customizations |
| `ingress-tailscale.yaml` | Tailscale Ingress for external access with Let's Encrypt TLS |
| `argocd-cmd-params-cm.yaml` | Patch to disable HTTPS redirect (TLS terminates at Ingress) |
| `argocd-cm-patch.yaml` | Server URL, accounts, resource exclusions |
| `argocd-rbac-cm-patch.yaml` | Role bindings for the Authentik groups and bot accounts |
| `argocd-resources-patch.yaml` | Resource requests/limits for the ArgoCD components |
| `argocd-ssh-known-hosts-cm.yaml` | Upstream host keys plus forge's, under both spellings |
| `external-secret-repo-forge.yaml` | repo-creds for `forge.ops.eblu.me` (the `mirrors/*` repos) |
| `external-secret-repo-forge-alias.yaml` | repo-creds for `forge.eblu.me` (everything tracking blumeops) |
| `external-secret-webhook.yaml` | Merges `webhook.gogs.secret` into `argocd-secret` for the push webhook |
| `README.md` | This file |

## Notes

- Secrets are managed by External Secrets from the `blumeops` 1Password vault; the
  manual `kubectl create secret` steps above are bootstrap-only, for a cluster that
  does not yet have the operator.
- The credential templates (`repo-creds`) use a URL prefix to match all repos on forge,
  and ArgoCD selects the longest matching prefix.
- ArgoCD uses Tailscale Ingress with Let's Encrypt for TLS termination.
- After Authentik is up, prefer `argocd login argocd.ops.eblu.me --sso` over the admin password login above; admin is only needed during bootstrap or as break-glass.
