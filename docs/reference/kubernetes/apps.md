---
title: Apps
tags:
  - kubernetes
  - argocd
---

# ArgoCD Applications

Registry of all applications deployed via [[argocd]].

## Application Registry

| App | Namespace | Path/Source | Service |
|-----|-----------|-------------|---------|
| `apps` | argocd | `argocd/apps/` | App-of-apps root |
| `argocd` | argocd | `argocd/manifests/argocd/` | [[argocd]] |
| `tailscale-operator` | tailscale | `argocd/manifests/tailscale-operator/` | [[tailscale-operator]] |
| `1password-connect` | 1password | `argocd/manifests/1password-connect/` | [[1password]] |
| `external-secrets` | external-secrets | Helm chart | [[1password]] |
| `external-secrets-config` | external-secrets | `argocd/manifests/external-secrets-config/` | [[1password]] |
| `cloudnative-pg` | cnpg-system | Helm chart (forge mirror) | PostgreSQL operator |
| `blumeops-pg` | databases | `argocd/manifests/databases/` | [[postgresql]] |
| `prometheus` | monitoring | `argocd/manifests/prometheus/` | [[prometheus]] |
| `loki` | monitoring | `argocd/manifests/loki/` | [[loki]] |
| `grafana` | monitoring | Helm chart (forge mirror) | [[grafana]] |
| `grafana-config` | monitoring | `argocd/manifests/grafana-config/` | [[grafana]] |
| `immich` | immich | Helm chart | [[immich]] |
| `alloy-k8s` | alloy | `argocd/manifests/alloy-k8s/` | [[alloy|Alloy]] |
| `kube-state-metrics` | monitoring | `argocd/manifests/kube-state-metrics/` | K8s metrics |
| `miniflux` | miniflux | `argocd/manifests/miniflux/` | [[miniflux]] |
| `kiwix` | kiwix | `argocd/manifests/kiwix/` | [[kiwix]] |
| `torrent` | torrent | `argocd/manifests/torrent/` | [[transmission]] |
| `navidrome` | navidrome | `argocd/manifests/navidrome/` | [[navidrome]] |
| `teslamate` | teslamate | `argocd/manifests/teslamate/` | [[teslamate]] |
| `forgejo-runner` | forgejo-runner | `argocd/manifests/forgejo-runner/` | [[forgejo]] CI |

## Sync Policies

| Application | Policy | Rationale |
|-------------|--------|-----------|
| `apps` | Automated | Picks up new Application manifests |
| All others | Manual | Explicit control over deployments |

## Related

- [[argocd]] - GitOps platform details
- [[cluster|Cluster]] - Kubernetes infrastructure
