# Phase 2: Grafana Migration (Pilot)

**Goal**: Migrate Grafana as lowest-risk pilot service

**Status**: Complete (2026-01-19)

**Prerequisites**: [Phase 1](P1_k8s_infrastructure.complete.md) complete

---

## Overview

This phase migrates Grafana from Homebrew/Ansible on indri to Kubernetes, establishing the pattern for future service migrations. Additionally, we establish the pattern of mirroring Helm chart repositories to forge for resilience and GitOps consistency.

---

## Key Decisions

### Helm Chart Mirroring

**Problem**: P1 uses external Helm repos which creates external dependencies.

**Solution**: Mirror Helm chart Git repositories to forge, reference charts from git path.

ArgoCD auto-detects Helm charts when a directory contains `Chart.yaml`. No build step needed.

| Chart | Upstream Git Repo | Forge Mirror | Chart Path |
|-------|-------------------|--------------|------------|
| cloudnative-pg | `github.com/cloudnative-pg/charts` | `forge/eblume/cloudnative-pg-charts` | `charts/cloudnative-pg/` |
| grafana | `github.com/grafana/helm-charts` | `forge/eblume/grafana-helm-charts` | `charts/grafana/` |

### Database Storage

Use SQLite with 1Gi PVC (not k8s PostgreSQL). Grafana stores minimal persistent data and dashboards are git-provisioned.

### Datasource URLs

From k8s pods, use `host.containers.internal` to reach indri services:
- Prometheus: `http://host.containers.internal:9090`
- Loki: `http://host.containers.internal:3100` (requires ansible change to bind 0.0.0.0)

### Ingress

Tailscale Ingress with Let's Encrypt TLS (following ArgoCD pattern), with `crio-compat` proxy class.

### Secrets Management

Admin password stored in 1Password, injected manually via `op inject`. Future: migrate to External Secrets Operator or similar.

---

## Prerequisites

### 0.1 Mirror Helm Chart Repos to Forge

**User action**: Create mirrors in forge:

1. **CloudNativePG charts** (fix existing P1 app):
   - Mirror: `https://github.com/cloudnative-pg/charts`
   - To: `forge.tail8d86e.ts.net/eblume/cloudnative-pg-charts`

2. **Grafana helm-charts** (new):
   - Mirror: `https://github.com/grafana/helm-charts`
   - To: `forge.tail8d86e.ts.net/eblume/grafana-helm-charts`

### 0.2 Update Loki to Bind 0.0.0.0

**File**: `ansible/roles/loki/templates/loki-config.yaml.j2`

Add under `server:`:
```yaml
http_listen_address: 0.0.0.0
```

Deploy: `mise run provision-indri -- --tags loki`

---

## Steps

### 1. Fix CloudNativePG to Use Forge Mirror

Update `argocd/apps/cloudnative-pg.yaml` to use forge-mirrored chart:

```yaml
sources:
  - repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/cloudnative-pg-charts.git
    targetRevision: cloudnative-pg-0.23.0  # git tag
    path: charts/cloudnative-pg
    helm:
      releaseName: cloudnative-pg
      valueFiles:
        - $values/argocd/manifests/cloudnative-pg/values.yaml
  - repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    ref: values
```

---

### 2. Create Grafana Helm Values

**File**: `argocd/manifests/grafana/values.yaml`

```yaml
admin:
  existingSecret: grafana-admin
  userKey: admin-user
  passwordKey: admin-password

persistence:
  enabled: true
  type: pvc
  size: 1Gi

grafana.ini:
  server:
    root_url: https://grafana.tail8d86e.ts.net
  analytics:
    check_for_updates: false
    reporting_enabled: false

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        uid: prometheus
        url: http://host.containers.internal:9090
        isDefault: true
        editable: false
      - name: Loki
        type: loki
        access: proxy
        uid: loki
        url: http://host.containers.internal:3100
        editable: false

sidecar:
  dashboards:
    enabled: true
    label: grafana_dashboard
    labelValue: "1"

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

---

### 3. Create Grafana ArgoCD Application

**File**: `argocd/apps/grafana.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/grafana-helm-charts.git
      targetRevision: grafana-8.8.2
      path: charts/grafana
      helm:
        releaseName: grafana
        valueFiles:
          - $values/argocd/manifests/grafana/values.yaml
    - repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

---

### 4. Create Grafana Config Application

**File**: `argocd/apps/grafana-config.yaml`

Deploys Tailscale Ingress and Dashboard ConfigMaps from `argocd/manifests/grafana-config/`.

---

### 5. Create Grafana Config Manifests

**Directory**: `argocd/manifests/grafana-config/`

Contents:
- `kustomization.yaml`
- `ingress-tailscale.yaml` - Tailscale Ingress for `grafana.tail8d86e.ts.net`
- `secret-admin.yaml.tpl` - Admin password template (1Password-backed)
- `README.md` - Notes on secrets management
- `dashboards/configmap-*.yaml` - 9 dashboard ConfigMaps

**Ingress**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-tailscale
  namespace: monitoring
  annotations:
    tailscale.com/proxy-class: "crio-compat"
spec:
  ingressClassName: tailscale
  defaultBackend:
    service:
      name: grafana
      port:
        number: 80
  tls:
    - hosts:
        - grafana
```

**Secret template** (`secret-admin.yaml.tpl`):
```yaml
# Apply: op inject -i secret-admin.yaml.tpl | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: monitoring
type: Opaque
stringData:
  admin-user: admin
  admin-password: {{ op://vg6xf6vvfmoh5hqjjhlhbeoaie/oxkcr3xtxnewy7noep2izvyr6y/password }}
```

**Dashboard ConfigMaps**: Convert each JSON from `ansible/roles/grafana/files/dashboards/` to ConfigMap with label `grafana_dashboard: "1"`.

---

### 6. Deploy to Kubernetes

```bash
# Create namespace and secret
ki create namespace monitoring
op inject -i argocd/manifests/grafana-config/secret-admin.yaml.tpl | ki apply -f -

# Push changes and sync
argocd app sync grafana
argocd app sync grafana-config
```

---

### 7. Tailscale Service Cutover

Remove `svc:grafana` from `ansible/roles/tailscale_serve/defaults/main.yml`, then:

```bash
mise run provision-indri -- --tags tailscale-serve
```

---

### 8. Stop Brew Grafana

```bash
ssh indri 'brew services stop grafana'
```

---

### 9. Retire Ansible Grafana Role

Once k8s Grafana is verified working:

1. **Remove role from playbook** - Delete grafana role entry from `ansible/playbooks/indri.yml`

2. **Delete the role directory** - `rm -rf ansible/roles/grafana/`

3. **Update zk documentation** - Note in `~/code/personal/zk/1767747119-YCPO.md` that Grafana is now k8s-hosted

---

## New Files

| Path | Purpose |
|------|---------|
| `argocd/apps/grafana.yaml` | Grafana Helm chart Application |
| `argocd/apps/grafana-config.yaml` | Grafana config Application |
| `argocd/manifests/grafana/values.yaml` | Helm values |
| `argocd/manifests/grafana-config/kustomization.yaml` | Kustomize config |
| `argocd/manifests/grafana-config/ingress-tailscale.yaml` | Tailscale Ingress |
| `argocd/manifests/grafana-config/secret-admin.yaml.tpl` | Admin password template |
| `argocd/manifests/grafana-config/README.md` | Secrets management notes |
| `argocd/manifests/grafana-config/dashboards/configmap-*.yaml` | 9 dashboard ConfigMaps |

## Modified Files

| Path | Change |
|------|--------|
| `argocd/apps/cloudnative-pg.yaml` | Switch to forge-mirrored chart |
| `ansible/roles/loki/templates/loki-config.yaml.j2` | Add `http_listen_address: 0.0.0.0` |
| `ansible/roles/tailscale_serve/defaults/main.yml` | Remove `svc:grafana` |
| `ansible/playbooks/indri.yml` | Remove grafana role |

## Deleted Files

| Path | Reason |
|------|--------|
| `ansible/roles/grafana/` | Replaced by k8s deployment |

---

## Verification

- [x] Loki accessible from k8s pods
- [x] Prometheus accessible from k8s pods
- [x] Grafana pod running in `monitoring` namespace
- [x] Grafana Ingress active
- [x] https://grafana.tail8d86e.ts.net loads
- [x] All 9 dashboards visible
- [x] Prometheus datasource queries work
- [x] Loki datasource queries work

---

## Rollback

1. Re-add `svc:grafana` to ansible tailscale_serve
2. `mise run provision-indri -- --tags tailscale-serve,grafana`
3. `argocd app delete grafana grafana-config --cascade`

---

## Implementation Notes

*Added during implementation for retrospective review*

### SSH Credential Management

**Issue**: Initial plan used HTTPS URLs for forge-mirrored Helm chart repos, but ArgoCD in cluster couldn't resolve `forge.tail8d86e.ts.net` (MagicDNS not available inside cluster).

**Solution**: Use SSH URLs for all forge repos. Created a **credential template** (`repo-creds-forge`) that matches all repos under `ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/` using URL prefix matching. This allows a single SSH key (added to Forgejo user, not as deploy key) to work for all repos.

### SSH Host Key for ArgoCD

**Issue**: ArgoCD's known_hosts didn't include indri's SSH host key, causing `knownhosts: key is unknown` errors.

**Solution**: Added `argocd-ssh-known-hosts-cm.yaml` as a kustomize patch to include indri's host key alongside the upstream defaults.

**Gotcha**: Kustomize patches must **not specify namespace** - the namespace transformation happens *after* patch matching. Our patch had `namespace: argocd` which caused "no matches for Id" errors until removed.

### Tailscale Hostname Cutover

**Issue**: After removing `svc:grafana` from ansible's tailscale_serve config, the k8s Ingress still got a numbered hostname (`grafana-1.tail8d86e.ts.net`).

**Solution**: The old `svc:grafana` service remained registered in Tailscale admin console even after clearing its serve config. **Manual deletion in Tailscale admin console** was required to free the `grafana` hostname for the k8s Ingress to claim. After deletion, recreating the Ingress picked up the correct hostname.

### ArgoCD Workflow Decision

During implementation, we established the pattern for GitOps workflow:

- **All apps target `main` branch** (not feature branches)
- Manual sync policy on workload apps = merge doesn't auto-deploy
- Workflow: feature branch → PR → merge to main → `argocd app sync <name>`
- For testing: temporarily set one app to feature branch via `argocd app set --revision`

This avoids the friction of switching `targetRevision` in manifests during development.

### Bootstrap Dependencies

Some resources must be applied manually before ArgoCD can manage itself:

1. **SSH known_hosts** - chicken-and-egg: ArgoCD can't sync the config that adds the host key
2. **Credential secrets** - `repo-creds-forge` must exist before ArgoCD can pull from forge

These are documented in `argocd/manifests/argocd/README.md` as bootstrap steps.

### Actual Versions Used

- Grafana Helm chart: `grafana-8.8.2` (tag in grafana-helm-charts repo)
- CloudNativePG Helm chart: `cloudnative-pg-v0.23.0` (tag in cloudnative-pg-charts repo)
- Grafana version: 11.4.0
