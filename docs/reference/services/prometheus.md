---
title: Prometheus
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
| **Tailscale URL** | https://prometheus.tail8d86e.ts.net |
| **Namespace** | `monitoring` |
| **Image** | `prom/prometheus:v3.2.1` |
| **Storage** | 50Gi PVC |
| **Manifests** | `argocd/manifests/prometheus/` |

## Data Sources

### Remote Write (from Alloy)
- Indri system metrics via [[services/alloy|Alloy]] remote_write
- Textfile metrics: minikube, borgmatic, zot, jellyfin

### Scrape Targets

| Target | Metrics |
|--------|---------|
| `sifaka:9100` | [[storage/sifaka|Sifaka]] NAS (node_exporter) |
| `cnpg-metrics.tail8d86e.ts.net:9187` | [[services/postgresql|CloudNativePG]] metrics |
| `kube-state-metrics.monitoring.svc:8080` | Kubernetes resource metrics |

## Related

- [[services/alloy|Alloy]] - Metrics collector
- [[services/grafana|Grafana]] - Visualization
- [[services/loki|Loki]] - Logs counterpart
