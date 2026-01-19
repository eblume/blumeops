# Phase 1: Kubernetes Infrastructure

**Goal**: Tailscale operator, ArgoCD, CloudNativePG operator, PostgreSQL cluster

**Status**: In Progress

**Prerequisites**: [Phase 0](P0_foundation.complete.md) complete

---

## Overview

Phase 1 establishes the k8s control plane infrastructure:
1. **Tailscale operator** - Exposes services on the tailnet
2. **ArgoCD** - GitOps continuous delivery
3. **CloudNativePG** - PostgreSQL operator
4. **PostgreSQL cluster** - Database for future app migrations

The deployment follows a bootstrap pattern:
- First two components deployed via `kubectl apply -k` (no GitOps yet)
- ArgoCD then takes over management of all components including itself
- All subsequent deployments use ArgoCD

---

## Kubernetes Tags Overview

| Tag | Purpose | Applied To |
|-----|---------|------------|
| `tag:k8s-api` | Controls access to the K8s API server | indri (Phase 0.14) |
| `tag:k8s-operator` | Identifies the Tailscale K8s Operator | OAuth client for operator |
| `tag:k8s` | Default tag for operator-managed resources | Proxies, services, ingresses created by operator |

**Ownership chain**: `tag:k8s-operator` must own `tag:k8s` so the operator can assign that tag to devices it creates.

---

## PostgreSQL Migration Strategy

The k8s PostgreSQL cluster will eventually replace the brew PostgreSQL on indri.

| Phase | `pg.tail8d86e.ts.net` points to | Miniflux connects to |
|-------|--------------------------------|---------------------|
| Current | brew PostgreSQL (indri) | `pg.tail8d86e.ts.net` |
| Phase 1 | brew PostgreSQL (indri) | `pg.tail8d86e.ts.net` (no change) |
| Phase 4 | brew PostgreSQL (indri) | k8s PG (internal, after miniflux migrates to k8s) |
| Post-Phase 4 | k8s PostgreSQL | k8s PG (internal) |
| Cleanup | k8s PostgreSQL | k8s PG (internal) |

This allows zero-downtime migration - the Tailscale service switches after apps are migrated.

---

## Steps

### 1. Update Pulumi ACLs for k8s workloads ✓

**Status**: Complete

Added to `pulumi/policy.hujson`:
- `tag:k8s-operator` - for the operator OAuth client
- `tag:k8s` - for operator-managed resources (owned by `tag:k8s-operator`)
- Grant for `tag:k8s` → `tag:registry` access

---

### 2. Create Tailscale OAuth client ✓

**Status**: Complete

OAuth client stored in 1Password (vault: `vg6xf6vvfmoh5hqjjhlhbeoaie`, item: `2it22lavwgbxdskoaxanej354q`)

**Configuration used:**
- Tags: `tag:k8s-operator`
- Devices write scope tag: `tag:k8s`
- Scopes: Devices Core (R/W), Auth Keys (R/W), Services (Write)

---

### 3. Deploy Tailscale Kubernetes Operator (Bootstrap)

Deploy via `kubectl apply -k` - will be migrated to ArgoCD management in Step 5.

**Setup manifests directory:**
```bash
mkdir -p argocd/manifests/tailscale-operator
cd argocd/manifests/tailscale-operator

# Download static manifest from Tailscale repo
curl -sL https://raw.githubusercontent.com/tailscale/tailscale/main/cmd/k8s-operator/deploy/manifests/operator.yaml -o operator.yaml

# Download CRDs
curl -sL https://raw.githubusercontent.com/tailscale/tailscale/main/cmd/k8s-operator/deploy/crds/tailscale.com_connectors.yaml -o crds/connectors.yaml
curl -sL https://raw.githubusercontent.com/tailscale/tailscale/main/cmd/k8s-operator/deploy/crds/tailscale.com_proxyclasses.yaml -o crds/proxyclasses.yaml
# ... (other CRDs as needed)
```

**Create kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: tailscale-system
resources:
  - operator.yaml
secretGenerator:
  - name: operator-oauth
    namespace: tailscale-system
    literals:
      - client_id=PLACEHOLDER
      - client_secret=PLACEHOLDER
generatorOptions:
  disableNameSuffixHash: true
```

**Deploy:**
```bash
# Get credentials from 1Password and create secret manually (kustomize secretGenerator is for reference)
CLIENT_ID=$(op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get 2it22lavwgbxdskoaxanej354q --fields client-id --reveal)
CLIENT_SECRET=$(op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get 2it22lavwgbxdskoaxanej354q --fields client-secret --reveal)

kubectl create namespace tailscale-system
kubectl create secret generic operator-oauth \
  --namespace tailscale-system \
  --from-literal=client_id=$CLIENT_ID \
  --from-literal=client_secret=$CLIENT_SECRET

# Apply operator manifests
kubectl apply -k argocd/manifests/tailscale-operator/
```

**Verification:**
```bash
kubectl get pods -n tailscale-system
# Expected: operator pod Running

kubectl logs -n tailscale-system -l app.kubernetes.io/name=tailscale-operator
```

---

### 4. Deploy ArgoCD

Deploy ArgoCD and expose via Tailscale as `argocd.tail8d86e.ts.net`.

**Prerequisites:**
- Add `tag:argocd` to Pulumi ACLs
- Create Tailscale service `argocd` in admin console

**Setup manifests:**
```bash
mkdir -p argocd/manifests/argocd

# Download ArgoCD install manifest
curl -sL https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -o argocd/manifests/argocd/install.yaml
```

**Create kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - install.yaml
  - service-tailscale.yaml  # LoadBalancer for Tailscale exposure
```

**Create service-tailscale.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-tailscale
  namespace: argocd
  annotations:
    tailscale.com/hostname: "argocd"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    app.kubernetes.io/name: argocd-server
  ports:
    - name: https
      port: 443
      targetPort: 8080
```

**Deploy:**
```bash
kubectl create namespace argocd
kubectl apply -k argocd/manifests/argocd/
```

**Get initial admin password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Verification:**
- https://argocd.tail8d86e.ts.net loads
- Can login with admin / <initial-password>

**Post-setup:**
1. Change admin password, store in 1Password
2. Configure git repo connection to `github.com/eblume/blumeops` (public, no auth needed)
   - Note: Using GitHub mirror since ArgoCD can't easily reach forge without additional networking

---

### 5. Migrate Tailscale Operator to ArgoCD

Create ArgoCD Application to manage the Tailscale operator.

**Create argocd/apps/tailscale-operator.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tailscale-operator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/tailscale-operator
  destination:
    server: https://kubernetes.default.svc
    namespace: tailscale-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Apply:**
```bash
kubectl apply -f argocd/apps/tailscale-operator.yaml
```

**Note on secrets:** The OAuth secret was created manually in Step 3. For GitOps, consider:
- Sealed Secrets
- External Secrets Operator
- SOPS

For now, the secret remains manually managed outside of ArgoCD.

---

### 6. Deploy CloudNativePG via ArgoCD

**Setup manifests:**
```bash
mkdir -p argocd/manifests/cloudnative-pg

# Download CNPG operator manifest
curl -sL https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml -o argocd/manifests/cloudnative-pg/operator.yaml
```

**Create kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - operator.yaml
```

**Create ArgoCD Application (argocd/apps/cloudnative-pg.yaml):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudnative-pg
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/cloudnative-pg
  destination:
    server: https://kubernetes.default.svc
    namespace: cnpg-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Apply:**
```bash
kubectl apply -f argocd/apps/cloudnative-pg.yaml
```

**Verification:**
```bash
kubectl get pods -n cnpg-system
# Expected: cnpg-controller-manager Running
```

---

### 7. Create PostgreSQL Cluster via ArgoCD

Create the database cluster. **Not exposed via Tailscale yet** - internal only until apps migrate.

**Create argocd/manifests/databases/blumeops-pg.yaml:**
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: blumeops-pg
  namespace: databases
spec:
  instances: 1
  storage:
    size: 10Gi
    storageClass: standard
  monitoring:
    enablePodMonitor: true
  bootstrap:
    initdb:
      database: miniflux
      owner: miniflux
```

**Create kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: databases
resources:
  - blumeops-pg.yaml
```

**Create ArgoCD Application (argocd/apps/blumeops-pg.yaml):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: blumeops-pg
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/databases
  destination:
    server: https://kubernetes.default.svc
    namespace: databases
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Apply:**
```bash
kubectl apply -f argocd/apps/blumeops-pg.yaml
```

**Verification:**
```bash
kubectl get cluster -n databases
# Expected: blumeops-pg with STATUS "Cluster in healthy state"

kubectl get pods -n databases
# Expected: blumeops-pg-1 Running

# Get connection secret
kubectl -n databases get secret blumeops-pg-app -o jsonpath='{.data.uri}' | base64 -d
```

---

### 8. Create App-of-Apps Root Application

Once all components are deployed, create a root application to manage all apps.

**Create argocd/apps/root.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/eblume/blumeops.git
    targetRevision: main
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Apply:**
```bash
kubectl apply -f argocd/apps/root.yaml
```

Now ArgoCD manages itself and all other applications via the app-of-apps pattern.

---

## New Files Summary

```
argocd/
  apps/
    root.yaml                    # App-of-apps root
    tailscale-operator.yaml      # Tailscale operator app
    cloudnative-pg.yaml          # CNPG operator app
    blumeops-pg.yaml             # PostgreSQL cluster app
  manifests/
    tailscale-operator/
      kustomization.yaml
      operator.yaml
    argocd/
      kustomization.yaml
      install.yaml
      service-tailscale.yaml
    cloudnative-pg/
      kustomization.yaml
      operator.yaml
    databases/
      kustomization.yaml
      blumeops-pg.yaml
```

---

## Pulumi ACL Updates Required

Add to `pulumi/policy.hujson`:
```hujson
"tag:argocd": ["autogroup:admin", "tag:blumeops"],
```

Add to Erich's test accept list:
```hujson
"accept": [..., "tag:argocd:443"],
```

Add to Allison's deny list:
```hujson
"deny": [..., "tag:argocd:443"],
```

---

## Verification Checklist

```bash
# 1. Tailscale operator running
kubectl get pods -n tailscale-system

# 2. ArgoCD accessible
curl -k https://argocd.tail8d86e.ts.net/healthz

# 3. CloudNativePG operator running
kubectl get pods -n cnpg-system

# 4. PostgreSQL cluster healthy
kubectl get cluster -n databases

# 5. All ArgoCD apps synced
kubectl get applications -n argocd
# All should show STATUS: Synced, HEALTH: Healthy
```

---

## Rollback

```bash
# Remove ArgoCD apps (will cascade delete managed resources)
kubectl delete application -n argocd root
kubectl delete application -n argocd blumeops-pg
kubectl delete application -n argocd cloudnative-pg
kubectl delete application -n argocd tailscale-operator

# Remove ArgoCD
kubectl delete -k argocd/manifests/argocd/
kubectl delete namespace argocd

# Remove namespaces
kubectl delete namespace databases
kubectl delete namespace cnpg-system
kubectl delete namespace tailscale-system

# Revert ACL changes
git checkout pulumi/policy.hujson
mise run tailnet-up
```

---

## Implementation Notes (Deviations from Plan)

*Added during implementation for retrospective review*

### Git Source: Forge Instead of GitHub

**Plan**: Use GitHub mirror (`github.com/eblume/blumeops`)
**Actual**: Use internal Forgejo (`ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git`)

**Why**: User preference to use internal infrastructure, accepting circular dependency for later.

**Required changes**:
- Deploy key added to forge for ArgoCD SSH access
- Repository secret `repo-forge` with SSH private key from 1Password
- Discovered: `op read` requires `?ssh-format=openssh` query parameter for ArgoCD-compatible key format
- Egress proxy service to reach forge from cluster (targets `indri.tail8d86e.ts.net` not `forge.tail8d86e.ts.net` due to Tailscale Serve limitation)
- DNSConfig CRD for cluster-to-tailnet MagicDNS resolution
- ACL grant: `tag:k8s` → `tag:homelab` on ports 3001 (HTTP) and 2200 (SSH)

### ArgoCD Exposure: Ingress Instead of LoadBalancer

**Plan**: LoadBalancer service with `tailscale.com/hostname` annotation
**Actual**: Tailscale Ingress with Let's Encrypt TLS termination

**Why**: Ingress provides automatic TLS certificates and is the recommended approach.

**File**: `argocd/manifests/argocd/service-tailscale.yaml` uses `kind: Ingress` with `ingressClassName: tailscale`

### Namespace: `tailscale` Instead of `tailscale-system`

**Plan**: `tailscale-system` namespace
**Actual**: `tailscale` namespace

**Why**: Matches upstream Tailscale operator defaults.

### Sync Policy: Manual Instead of Automated

**Plan**: `syncPolicy.automated` with prune and selfHeal
**Actual**: Manual sync policy for workload apps; auto-sync only for app-of-apps

**Why**: User preference for explicit control over deployments during initial migration phase.

**Pattern**:
- `apps.yaml` (app-of-apps): auto-sync to pick up new Application manifests
- All workload apps: manual sync requires `argocd app sync <name>`

### CloudNativePG: Helm Chart Instead of Raw Manifest

**Plan**: Download raw CNPG manifest
**Actual**: Multi-source Application using official Helm chart from `https://cloudnative-pg.github.io/charts`

**Why**: Helm chart is the officially supported distribution method.

**Additional fix**: Required `ServerSideApply=true` sync option due to large CRD exceeding annotation size limit.

### App-of-Apps: Named `apps` Instead of `root`

**Plan**: `argocd/apps/root.yaml`
**Actual**: `argocd/apps/apps.yaml` with Application named `apps`

**Why**: Clearer naming; `apps` manages apps, `argocd` manages itself.

### ArgoCD Self-Management Added

**Plan**: Not explicitly planned
**Actual**: `argocd/apps/argocd.yaml` Application for ArgoCD self-management

**Why**: Standard GitOps pattern - ArgoCD manages its own deployment after bootstrap.

### CRI-O Registry Mirror for Zot

**Plan**: Not in original plan
**Actual**: Configured CRI-O to use zot as pull-through cache for docker.io, ghcr.io, quay.io

**Why**: Reduces external bandwidth, speeds up pulls, avoids rate limits.

**Implementation**: Ansible `minikube` role applies `/etc/containers/registries.conf.d/zot-mirror.conf` inside minikube VM using stable hostname `host.containers.internal:5050`.

### ProxyClass for CRI-O Image Compatibility

**Plan**: Not mentioned
**Actual**: Required `ProxyClass` with fully-qualified image paths (`docker.io/tailscale/...`)

**Why**: CRI-O requires fully-qualified image references; default Tailscale operator uses short names.

### Actual File Structure

```
argocd/
  apps/
    apps.yaml                    # App-of-apps (auto-sync)
    argocd.yaml                  # ArgoCD self-management (manual sync)
    tailscale-operator.yaml      # Tailscale operator (manual sync)
    cloudnative-pg.yaml          # CNPG operator via Helm (manual sync)
  manifests/
    tailscale-operator/
      kustomization.yaml
      operator.yaml
      proxyclass.yaml            # CRI-O compatibility
      dnsconfig.yaml             # Cluster-to-tailnet DNS
      egress-forge.yaml          # Egress proxy for forge
      secret.yaml.tpl            # OAuth secret template (manual)
      README.md
    argocd/
      kustomization.yaml         # Uses remote base from upstream
      service-tailscale.yaml     # Ingress (not LoadBalancer)
      argocd-cmd-params-cm.yaml  # Disable HTTPS redirect
      repo-forge-secret.yaml.tpl # SSH key template (manual)
      README.md
    cloudnative-pg/
      values.yaml                # Helm values (currently minimal)
      README.md
```

### Bootstrap Commands (Actual)

```bash
# 1. Create namespaces
kubectl create namespace tailscale
kubectl create namespace argocd

# 2. Apply secrets (manual, uses 1Password)
op inject -i argocd/manifests/tailscale-operator/secret.yaml.tpl | kubectl apply -f -

PRIV_KEY=$(op read "op://vg6xf6vvfmoh5hqjjhlhbeoaie/csjncynh6htjvnh2l2da65y32q/private key?ssh-format=openssh")$'\n' && \
kubectl create secret generic repo-forge -n argocd \
  --from-literal=type=git \
  --from-literal=url='ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git' \
  --from-literal=insecure=true \
  --from-literal=sshPrivateKey="$PRIV_KEY" && \
kubectl label secret repo-forge -n argocd argocd.argoproj.io/secret-type=repository

# 3. Bootstrap tailscale-operator
kubectl apply -k argocd/manifests/tailscale-operator/

# 4. Bootstrap ArgoCD
kubectl apply -k argocd/manifests/argocd/

# 5. Login and change password
argocd login argocd.tail8d86e.ts.net --username admin --grpc-web
argocd account update-password

# 6. Apply ArgoCD Applications
kubectl apply -f argocd/apps/argocd.yaml
kubectl apply -f argocd/apps/apps.yaml

# 7. Sync workloads
argocd app sync tailscale-operator
argocd app sync cloudnative-pg
```
