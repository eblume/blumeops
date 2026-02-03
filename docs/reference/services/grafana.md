---
title: Grafana
tags:
  - service
  - observability
---

# Grafana

Dashboards and visualization for BlumeOps observability.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://grafana.ops.eblu.me |
| **Tailscale URL** | https://grafana.tail8d86e.ts.net |
| **Namespace** | `monitoring` |
| **Helm Chart** | grafana (mirrored to forge) |
| **Values** | `argocd/manifests/grafana/values.yaml` |

## Datasources

| Name | Type | Target |
|------|------|--------|
| Prometheus | prometheus | `prometheus.monitoring.svc.cluster.local:9090` |
| Loki | loki | `loki.monitoring.svc.cluster.local:3100` |
| TeslaMate | postgres | `blumeops-pg-rw.databases.svc.cluster.local:5432` |

## Dashboard Provisioning

Dashboards are ConfigMaps with label `grafana_dashboard: "1"`.

Location: `argocd/manifests/grafana-config/dashboards/`

Optional annotation: `grafana_folder: "FolderName"`

## Key Dashboards

- macOS System - Host metrics for indri
- Minikube - Kubernetes cluster overview
- Borgmatic Backups - Backup status and trends
- Services Health - HTTP probe results
- TeslaMate (18 dashboards) - Vehicle data

## Related

- [[prometheus|Prometheus]] - Metrics datasource
- [[loki|Loki]] - Logs datasource
- [[alloy|Alloy]] - Data collector
