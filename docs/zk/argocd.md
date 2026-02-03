---
id: argocd
aliases:
  - argo-cd
tags:
  - blumeops
---

# ArgoCD Management Log

ArgoCD provides GitOps continuous delivery for the [[minikube]] cluster on Indri.

## Service Details

- URL: https://argocd.tail8d86e.ts.net
- Namespace: `argocd`
- Git source: `ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git`
- Manifests path: `argocd/`

## Sync Policy Decision

**Choice**: Manual sync for workload apps, auto-sync only for app-of-apps.

**Rationale** (decided 2026-01-19 during Phase 1 migration):
- During migration, we want explicit control over what gets deployed
- Auto-sync could deploy broken changes while we're still learning the stack
- The app-of-apps (`apps`) auto-syncs so new Application manifests appear automatically
- But those Applications have manual sync, so actual workload changes require `argocd app sync <name>`

**Pattern**:
| Application | Sync Policy | Why |
|-------------|-------------|-----|
| `apps` | Automated | Picks up new Application manifests from git |
| `argocd` | Manual | Self-management changes should be deliberate |
| `tailscale-operator` | Manual | Infrastructure changes need review |
| `cloudnative-pg` | Manual | Operator upgrades need care |
| `blumeops-pg` | Manual | Database changes are sensitive |
| `grafana` | Manual | Observability stack changes need review |
| `grafana-config` | Manual | Dashboard changes should be deliberate |
| `miniflux` | Manual | Application changes need review |
| `devpi` | Manual | PyPI proxy changes need review |

**Future consideration**: After migration stabilizes, consider enabling auto-sync for stable workloads. Keep manual sync for infrastructure (operators, databases).

## CLI Access

```bash
# Login (uses Tailscale for network, prompts for password)
argocd login argocd.tail8d86e.ts.net --grpc-web

# List apps
argocd app list

# Sync an app
argocd app sync <app-name>

# Check diff before sync
argocd app diff <app-name>

# Get app details
argocd app get <app-name>
```

## Applications

| App | Path | Description |
|-----|------|-------------|
| `apps` | `argocd/apps/` | App-of-apps root |
| `argocd` | `argocd/manifests/argocd/` | ArgoCD self-management |
| `tailscale-operator` | `argocd/manifests/tailscale-operator/` | Tailscale k8s operator |
| `cloudnative-pg` | Helm chart (forge mirror) | PostgreSQL operator |
| `blumeops-pg` | `argocd/manifests/databases/` | PostgreSQL cluster |
| `prometheus` | `argocd/manifests/prometheus/` | Metrics storage |
| `loki` | `argocd/manifests/loki/` | Log aggregation |
| `grafana` | Helm chart (forge mirror) | Grafana dashboards |
| `grafana-config` | `argocd/manifests/grafana-config/` | Grafana ingress & dashboards |
| `alloy-k8s` | `argocd/manifests/alloy-k8s/` | Pod log collection & service probes |
| `kube-state-metrics` | `argocd/manifests/kube-state-metrics/` | K8s resource metrics |
| `miniflux` | `argocd/manifests/miniflux/` | RSS feed reader |
| `devpi` | `argocd/manifests/devpi/` | PyPI caching proxy |
| `torrent` | `argocd/manifests/torrent/` | BitTorrent daemon |
| `kiwix` | `argocd/manifests/kiwix/` | Offline Wikipedia & ZIM archives |
| `forgejo-runner` | `argocd/manifests/forgejo-runner/` | Forgejo Actions CI runner (host mode) |

## Credentials

- Admin password stored in 1Password (updated from initial auto-generated password)
- Git access via deploy key (SSH) stored in 1Password

## Log

### 2026-01-23 (CI/CD Bootstrap Phase 1)
- Added `forgejo-runner` - Forgejo Actions CI runner
- Runner uses host mode (jobs run directly in runner container, no Docker needed)
- Labels: `ubuntu-latest`, `ubuntu-22.04`
- Note: Stock runner lacks Node.js, so `actions/checkout@v4` doesn't work - use git clone instead
- See [[forgejo]] for runner token management and workflow examples

### 2026-01-22 (Observability Cleanup)
- Added `alloy-k8s` - DaemonSet for automatic pod log collection and service health probes
- Added `kube-state-metrics` - provides k8s resource metrics (pod counts, resource requests, etc.)
- Enhanced Minikube dashboard with namespace filtering and resource usage panels
- Added "Services Health" dashboard with probe metrics for all k8s services
- Fixed macOS dashboard instance variable to only show macOS hosts
- Cleaned up stale data: removed old textfile metrics and directories from indri
- Removed stale `/opt/homebrew/var/loki` from borgmatic backup sources

### 2026-01-22 (Phase 7)
- **Migrated Prometheus and Loki to k8s** - completed observability stack migration
- Both now running as StatefulSets with 50Gi PVCs
- Exposed via Tailscale Ingress at `prometheus.tail8d86e.ts.net` and `loki.tail8d86e.ts.net`
- Grafana datasources updated to use k8s-internal service URLs
- Alloy rebuilt with CGO for Tailscale DNS resolution, pushes to k8s endpoints
- Retired ansible prometheus and loki roles from indri

### 2026-01-21 (Phase 6)
- Added torrent (Transmission BitTorrent) to k8s
- Added kiwix (offline Wikipedia & ZIM archives) to k8s
- NFS storage from sifaka for shared torrent/ZIM data

### 2026-01-20 (Phase 5)
- Added devpi (PyPI caching proxy) to k8s
- Custom container image in zot registry with devpi-server + devpi-web
- StatefulSet with 50Gi PVC for data persistence
- Changed `apps` Application to manual sync (was auto-sync with prune)

### 2026-01-19 (Phase 2)
- Migrated Grafana from Homebrew/Ansible to Kubernetes
- Helm chart repos now mirrored to forge (cloudnative-pg-charts, grafana-helm-charts)
- SSH credential template (`repo-creds-forge`) for all forge repos
- Added indri SSH host key to ArgoCD known_hosts
- Tailscale service cutover: deleted old svc:grafana from Tailscale admin to free hostname
- Retired ansible grafana role

### 2026-01-19 (Phase 1)
- Completed Phase 1 deployment
- Decided on manual sync policy for workloads
- Using internal [[forgejo]] as git source (not GitHub mirror)
- Exposed via Tailscale Ingress with Let's Encrypt TLS
