---
title: ArgoCD Applications
tags:
  - kubernetes
  - argocd
---

# ArgoCD Applications

Registry of all applications deployed via [[services/argocd|ArgoCD]].

## Application Registry

| App | Namespace | Path/Source | Service |
|-----|-----------|-------------|---------|
| `apps` | argocd | `argocd/apps/` | App-of-apps root |
| `argocd` | argocd | `argocd/manifests/argocd/` | [[services/argocd|ArgoCD]] |
| `tailscale-operator` | tailscale | `argocd/manifests/tailscale-operator/` | Tailscale k8s operator |
| `1password-connect` | 1password | `argocd/manifests/1password-connect/` | [[services/1password|1Password]] |
| `external-secrets` | external-secrets | Helm chart | [[services/1password|1Password]] |
| `external-secrets-config` | external-secrets | `argocd/manifests/external-secrets-config/` | [[services/1password|1Password]] |
| `cloudnative-pg` | cnpg-system | Helm chart (forge mirror) | PostgreSQL operator |
| `blumeops-pg` | databases | `argocd/manifests/databases/` | [[services/postgresql|PostgreSQL]] |
| `prometheus` | monitoring | `argocd/manifests/prometheus/` | [[services/prometheus|Prometheus]] |
| `loki` | monitoring | `argocd/manifests/loki/` | [[services/loki|Loki]] |
| `grafana` | monitoring | Helm chart (forge mirror) | [[services/grafana|Grafana]] |
| `grafana-config` | monitoring | `argocd/manifests/grafana-config/` | [[services/grafana|Grafana]] |
| `immich` | immich | Helm chart | [[services/immich|Immich]] |
| `alloy-k8s` | alloy | `argocd/manifests/alloy-k8s/` | [[services/alloy|Alloy]] |
| `kube-state-metrics` | monitoring | `argocd/manifests/kube-state-metrics/` | K8s metrics |
| `miniflux` | miniflux | `argocd/manifests/miniflux/` | [[services/miniflux|Miniflux]] |
| `kiwix` | kiwix | `argocd/manifests/kiwix/` | [[services/kiwix|Kiwix]] |
| `torrent` | torrent | `argocd/manifests/torrent/` | [[services/transmission|Transmission]] |
| `navidrome` | navidrome | `argocd/manifests/navidrome/` | [[services/navidrome|Navidrome]] |
| `teslamate` | teslamate | `argocd/manifests/teslamate/` | [[services/teslamate|TeslaMate]] |
| `forgejo-runner` | forgejo-runner | `argocd/manifests/forgejo-runner/` | [[services/forgejo|Forgejo]] CI |

## Sync Policies

| Application | Policy | Rationale |
|-------------|--------|-----------|
| `apps` | Automated | Picks up new Application manifests |
| All others | Manual | Explicit control over deployments |

## Related

- [[services/argocd|ArgoCD]] - GitOps platform details
- [[kubernetes/cluster|Cluster]] - Kubernetes infrastructure
