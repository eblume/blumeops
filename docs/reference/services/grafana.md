---
title: Grafana
modified: 2026-02-08
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

## Authentication

Grafana supports two login methods:

- **SSO via [[dex]]** — federated login through [[forgejo]] (`auth.generic_oauth`). Users click "Sign in with Dex", authenticate at Forgejo, and are redirected back as Admin.
- **Local admin** — break-glass login using the password from 1Password ("Grafana (blumeops)"). Always available if Dex is down.

The OIDC client secret is injected via [[external-secrets]] (`grafana-dex-oauth` secret in monitoring namespace).

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
- Docs APM - Request rate, latency, cache for docs.eblu.me
- Fly.io Proxy Health - Aggregate proxy health across all upstream services
- TeslaMate (18 dashboards) - Vehicle data

## Related

- [[dex]] - OIDC identity provider for SSO
- [[prometheus]] - Metrics datasource
- [[loki]] - Logs datasource
- [[alloy|Alloy]] - Data collector
