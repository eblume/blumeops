---
title: Prometheus
modified: 2026-03-23
last-reviewed: 2026-03-23
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
| **Image** | `registry.ops.eblu.me/blumeops/prometheus` (see `argocd/manifests/prometheus/kustomization.yaml` for current tag) |
| **Storage** | 50Gi PVC |
| **Manifests** | `argocd/manifests/prometheus/` |

## Data Sources

### Remote Write (from Alloy)
- Indri system metrics via [[alloy|Alloy]] remote_write
- Textfile metrics: minikube, borgmatic, zot, jellyfin
- [[flyio-proxy]] nginx metrics (`flyio_nginx_*`) via Alloy embedded in Fly.io container

### Scrape Targets

| Target | Metrics |
|--------|---------|
| `sifaka:9100` | [[sifaka|Sifaka]] NAS (node_exporter) |
| `blumeops-pg-metrics-tailscale.databases.svc.cluster.local:9187` | [[postgresql|CloudNativePG]] metrics |
| `kube-state-metrics.monitoring.svc:8080` | Kubernetes resource metrics |

## Related

- [[alloy|Alloy]] - Metrics collector
- [[grafana]] - Visualization
- [[loki]] - Logs counterpart
