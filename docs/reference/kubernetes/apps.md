---
title: ArgoCD Applications
tags:
  - kubernetes
  - argocd
---

# ArgoCD Applications

Registry of all applications deployed via [[ArgoCD]].

## Application Registry

| App | Namespace | Path/Source | Service |
|-----|-----------|-------------|---------|
| `apps` | argocd | `argocd/apps/` | App-of-apps root |
| `argocd` | argocd | `argocd/manifests/argocd/` | [[ArgoCD]] |
| `tailscale-operator` | tailscale | `argocd/manifests/tailscale-operator/` | Tailscale k8s operator |
| `1password-connect` | 1password | `argocd/manifests/1password-connect/` | [[1Password]] |
| `external-secrets` | external-secrets | Helm chart | [[1Password]] |
| `external-secrets-config` | external-secrets | `argocd/manifests/external-secrets-config/` | [[1Password]] |
| `cloudnative-pg` | cnpg-system | Helm chart (forge mirror) | PostgreSQL operator |
| `blumeops-pg` | databases | `argocd/manifests/databases/` | [[PostgreSQL]] |
| `prometheus` | monitoring | `argocd/manifests/prometheus/` | [[Prometheus]] |
| `loki` | monitoring | `argocd/manifests/loki/` | [[Loki]] |
| `grafana` | monitoring | Helm chart (forge mirror) | [[Grafana]] |
| `grafana-config` | monitoring | `argocd/manifests/grafana-config/` | [[Grafana]] |
| `immich` | immich | Helm chart | [[Immich]] |
| `alloy-k8s` | alloy | `argocd/manifests/alloy-k8s/` | [[Grafana Alloy|Alloy]] |
| `kube-state-metrics` | monitoring | `argocd/manifests/kube-state-metrics/` | K8s metrics |
| `miniflux` | miniflux | `argocd/manifests/miniflux/` | [[Miniflux]] |
| `kiwix` | kiwix | `argocd/manifests/kiwix/` | [[Kiwix]] |
| `torrent` | torrent | `argocd/manifests/torrent/` | [[Transmission]] |
| `navidrome` | navidrome | `argocd/manifests/navidrome/` | [[Navidrome]] |
| `teslamate` | teslamate | `argocd/manifests/teslamate/` | [[TeslaMate]] |
| `forgejo-runner` | forgejo-runner | `argocd/manifests/forgejo-runner/` | [[Forgejo]] CI |

## Sync Policies

| Application | Policy | Rationale |
|-------------|--------|-----------|
| `apps` | Automated | Picks up new Application manifests |
| All others | Manual | Explicit control over deployments |

## Related

- [[ArgoCD]] - GitOps platform details
- [[Kubernetes Cluster|Cluster]] - Kubernetes infrastructure
