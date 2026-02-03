---
title: ArgoCD Applications
tags:
  - kubernetes
  - argocd
---

# ArgoCD Applications

Registry of all applications deployed via [[reference/services/argocd|ArgoCD]].

## Application Registry

| App | Namespace | Path/Source | Service |
|-----|-----------|-------------|---------|
| `apps` | argocd | `argocd/apps/` | App-of-apps root |
| `argocd` | argocd | `argocd/manifests/argocd/` | [[reference/services/argocd|ArgoCD]] |
| `tailscale-operator` | tailscale | `argocd/manifests/tailscale-operator/` | Tailscale k8s operator |
| `1password-connect` | 1password | `argocd/manifests/1password-connect/` | [[reference/services/1password|1Password]] |
| `external-secrets` | external-secrets | Helm chart | [[reference/services/1password|1Password]] |
| `external-secrets-config` | external-secrets | `argocd/manifests/external-secrets-config/` | [[reference/services/1password|1Password]] |
| `cloudnative-pg` | cnpg-system | Helm chart (forge mirror) | PostgreSQL operator |
| `blumeops-pg` | databases | `argocd/manifests/databases/` | [[reference/services/postgresql|PostgreSQL]] |
| `prometheus` | monitoring | `argocd/manifests/prometheus/` | [[reference/services/prometheus|Prometheus]] |
| `loki` | monitoring | `argocd/manifests/loki/` | [[reference/services/loki|Loki]] |
| `grafana` | monitoring | Helm chart (forge mirror) | [[reference/services/grafana|Grafana]] |
| `grafana-config` | monitoring | `argocd/manifests/grafana-config/` | [[reference/services/grafana|Grafana]] |
| `immich` | immich | Helm chart | [[reference/services/immich|Immich]] |
| `alloy-k8s` | alloy | `argocd/manifests/alloy-k8s/` | [[reference/services/alloy|Alloy]] |
| `kube-state-metrics` | monitoring | `argocd/manifests/kube-state-metrics/` | K8s metrics |
| `miniflux` | miniflux | `argocd/manifests/miniflux/` | [[reference/services/miniflux|Miniflux]] |
| `kiwix` | kiwix | `argocd/manifests/kiwix/` | [[reference/services/kiwix|Kiwix]] |
| `torrent` | torrent | `argocd/manifests/torrent/` | [[reference/services/transmission|Transmission]] |
| `navidrome` | navidrome | `argocd/manifests/navidrome/` | [[reference/services/navidrome|Navidrome]] |
| `teslamate` | teslamate | `argocd/manifests/teslamate/` | [[reference/services/teslamate|TeslaMate]] |
| `forgejo-runner` | forgejo-runner | `argocd/manifests/forgejo-runner/` | [[reference/services/forgejo|Forgejo]] CI |

## Sync Policies

| Application | Policy | Rationale |
|-------------|--------|-----------|
| `apps` | Automated | Picks up new Application manifests |
| All others | Manual | Explicit control over deployments |

## Related

- [[reference/services/argocd|ArgoCD]] - GitOps platform details
- [[reference/kubernetes/cluster|Cluster]] - Kubernetes infrastructure
