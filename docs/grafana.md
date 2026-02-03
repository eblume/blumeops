---
id: grafana
aliases:
  - grafana
tags:
  - blumeops
---

# Grafana Management Log

Grafana provides dashboards and observability for [[blumeops]].

## Service Details

- URL: https://grafana.ops.eblu.me (also https://grafana.tail8d86e.ts.net)
- Namespace: `monitoring`
- Helm chart: grafana (mirrored to forge)
- Values: `argocd/manifests/grafana/values.yaml`
- Dashboards: `argocd/manifests/grafana-config/dashboards/`

## Embedding Note

Grafana panel embedding via iframes was attempted for Homepage but didn't work well:
- Homepage's iframe widget doesn't support width constraints (only height)
- Grafana's "Public Dashboards" feature doesn't support template variables or PostgreSQL datasources
- Anonymous auth would be required, which exposes all dashboards

Current config has `allow_embedding: false`. If revisiting this, see git history for the iframe attempt (2026-01-30).

## Datasources

| Name | Type | URL |
|------|------|-----|
| Prometheus | prometheus | `http://prometheus.monitoring.svc.cluster.local:9090` |
| Loki | loki | `http://loki.monitoring.svc.cluster.local:3100` |
| TeslaMate | postgres | `blumeops-pg-rw.databases.svc.cluster.local:5432` |

## Dashboard Provisioning

Dashboards are provisioned via ConfigMaps with label `grafana_dashboard: "1"`. The sidecar watches for these and loads them automatically.

To add a dashboard:
1. Create ConfigMap in `argocd/manifests/grafana-config/dashboards/`
2. Add label `grafana_dashboard: "1"`
3. Optionally add annotation `grafana_folder: "FolderName"` for organization
4. Sync the `grafana-config` ArgoCD app

## Log

### 2026-01-30
- Attempted Grafana iframe embeds for Homepage metrics panel
- Issues: width constraints don't work, some panels fail to load
- Reverted to authenticated-only access (no anonymous auth)

### 2026-01-19 (Phase 2)
- Migrated from Homebrew/Ansible to Kubernetes
- Helm chart mirrored to forge
- Exposed via Tailscale Ingress
