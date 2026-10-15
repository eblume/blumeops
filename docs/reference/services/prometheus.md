---
title: Prometheus
modified: 2026-10-15
last-reviewed: 2026-10-15
tags:
  - service
  - observability
---

# Prometheus

Metrics storage and querying for BlumeOps infrastructure.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://prometheus.ops.eblu.me |
| **Namespace** | `monitoring` |
| **Image** | `registry.ops.eblu.me/blumeops/prometheus` (see `argocd/manifests/prometheus-ringtail/kustomization.yaml` for current tag) |
| **Storage** | 20Gi PVC |
| **Manifests** | `argocd/manifests/prometheus-ringtail/` |
| **ArgoCD app** | `prometheus-ringtail` |

## Data Sources

### Remote Write (from Alloy)
- Indri system metrics via [[alloy|Alloy]] remote_write
- Ringtail Kubernetes metrics (kube-state-metrics, node, kubelet) via the alloy-ringtail DaemonSet
- Textfile metrics: borgmatic, zot, jellyfin, forgejo
- [[flyio-proxy]] nginx metrics (`flyio_nginx_*`) via Alloy embedded in the Fly.io container

### Scrape Targets

| Job | Target |
|-----|--------|
| `node-exporter-sifaka` | `nas.ops.eblu.me:9100` — [[sifaka]] NAS (via Caddy L4 on indri) |
| `smartctl-sifaka` | `nas.ops.eblu.me:9633` — [[sifaka]] NAS (via Caddy L4 on indri) |
| `cnpg-postgres` | `blumeops-pg-metrics.databases.svc:9187`, `immich-pg-metrics.databases.svc:9187` — [[postgresql]] |
| `prometheus` | `localhost:9090` — self-monitoring |
| `loki` | `loki.monitoring.svc:3100` |
| `tempo` | `tempo.monitoring.svc:3200` |
| `argocd` | `argocd-metrics.argocd.svc:8082` |
| `frigate` | `nvr.ops.eblu.me/api/metrics` |
| `birdnet-go` | `birdnet-go.birdnet-go.svc:8090` |

kube-state-metrics is deliberately not scraped here: alloy-ringtail scrapes
and remote-writes it instead.

## Related

- [[alloy|Alloy]] - Metrics collector
- [[grafana]] - Visualization
- [[loki]] - Logs counterpart
