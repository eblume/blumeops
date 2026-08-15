---
title: Apps
modified: 2026-07-17
last-reviewed: 2026-07-17
tags:
  - kubernetes
  - argocd
---

# ArgoCD Applications

Registry of all applications deployed via [[argocd]]. App names carry a
`-ringtail` suffix where they were migrated from the retired minikube
cluster (see [[retire-minikube]]); newer apps use bare names.

## Application Registry

| App | Namespace | Path/Source | Service |
|-----|-----------|-------------|---------|
| `apps` | argocd | `argocd/apps/` | App-of-apps root |
| `argocd` | argocd | `argocd/manifests/argocd/` | [[argocd]] |
| `tailscale-operator-ringtail` | tailscale | `argocd/manifests/tailscale-operator-ringtail/` | [[tailscale-operator]] |
| `1password-connect-ringtail` | 1password | `argocd/manifests/1password-connect/` | [[1password]] |
| `external-secrets-ringtail` | external-secrets | `argocd/manifests/external-secrets-ringtail/` | [[1password]] |
| `external-secrets-crds-ringtail` | external-secrets | `external-secrets` repo `config/crds/bases` | [[1password]] |
| `cloudnative-pg-ringtail` | cnpg-system | `mirrors/cloudnative-pg` release manifest | PostgreSQL operator |
| `databases-ringtail` | databases | `argocd/manifests/databases-ringtail/` | [[postgresql]] |
| `authentik` | authentik | `argocd/manifests/authentik/` | [[authentik]] |
| `prometheus-ringtail` | monitoring | `argocd/manifests/prometheus-ringtail/` | [[prometheus]] |
| `loki-ringtail` | monitoring | `argocd/manifests/loki-ringtail/` | [[loki]] |
| `tempo-ringtail` | monitoring | `argocd/manifests/tempo-ringtail/` | [[tempo]] |
| `grafana-ringtail` | monitoring | `argocd/manifests/grafana-ringtail/` | [[grafana]] |
| `grafana-config-ringtail` | monitoring | `argocd/manifests/grafana-config-ringtail/` | [[grafana]] |
| `kube-state-metrics-ringtail` | monitoring | `argocd/manifests/kube-state-metrics-ringtail/` | K8s metrics |
| `unpoller-ringtail` | monitoring | `argocd/manifests/unpoller-ringtail/` | [[unifi]] metrics poller |
| `alloy-ringtail` | alloy | `argocd/manifests/alloy-ringtail/` | [[alloy|Alloy]] |
| `alloy-tracing-ringtail` | alloy | `argocd/manifests/alloy-tracing-ringtail/` | [[alloy|Alloy]] (eBPF tracing) |
| `immich-ringtail` | immich | `argocd/manifests/immich-ringtail/` | [[immich]] |
| `frigate` | frigate | `argocd/manifests/frigate/` | [[frigate]] |
| `miniflux-ringtail` | miniflux | `argocd/manifests/miniflux-ringtail/` | [[miniflux]] |
| `kiwix-ringtail` | kiwix | `argocd/manifests/kiwix-ringtail/` | [[kiwix]] |
| `torrent-ringtail` | torrent | `argocd/manifests/torrent-ringtail/` | [[transmission]] |
| `navidrome-ringtail` | navidrome | `argocd/manifests/navidrome-ringtail/` | [[navidrome]] |
| `teslamate-ringtail` | teslamate | `argocd/manifests/teslamate-ringtail/` | [[teslamate]] |
| `mealie-ringtail` | mealie | `argocd/manifests/mealie-ringtail/` | [[mealie]] |
| `talos` | talos | `argocd/manifests/talos/` | [[talos]] |
| `paperless-ringtail` | paperless | `argocd/manifests/paperless-ringtail/` | [[paperless]] |
| `ollama` | ollama | `argocd/manifests/ollama/` | [[ollama]] |
| `nvidia-device-plugin` | nvidia-device-plugin | `argocd/manifests/nvidia-device-plugin/` | [[nvidia-device-plugin]] |
| `ntfy` | ntfy | `argocd/manifests/ntfy/` | [[ntfy]] |
| `homepage` | homepage | `argocd/manifests/homepage/` | Homepage dashboard (no card yet) |
| `shower` | shower | `argocd/manifests/shower/` | [[shower-app]] |
| `prowler` | prowler | `argocd/manifests/prowler/` | [[prowler]] |

No longer on Kubernetes: `cv` moved to indri (see [[cv]] and
[[cv-on-indri]]), and `forgejo-runner` is now a NixOS service on ringtail
pinned via the `nixpkgs-services` overlay (see [[forgejo-runner]]).

## Sync Policies

All applications, including the `apps` app-of-apps root, are **manual
sync** — deployments are explicit (`argocd app sync <app>`). To pick up a
newly added Application manifest: `argocd app sync apps`.

## Related

- [[argocd]] - GitOps platform details
- [[cluster|Cluster]] - Kubernetes infrastructure
- [[retire-minikube]] - Why most app names carry `-ringtail`
