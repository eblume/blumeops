---
title: Grafana
modified: 2026-02-28
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
| **Deployment** | Kustomize (`argocd/manifests/grafana/`) |
| **Image** | `registry.ops.eblu.me/blumeops/grafana` |

## Authentication

Grafana supports two login methods:

- **SSO via [[authentik]]** — OIDC login through Authentik (`auth.generic_oauth`). Users click "Sign in with Authentik", authenticate at Authentik, and are redirected back as Admin.
- **Local admin** — break-glass login using the password from 1Password ("Grafana (blumeops)"). Always available if Authentik is down.

The OIDC client secret is injected via [[external-secrets]] (`grafana-authentik-oauth` secret in monitoring namespace).

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

- [[build-grafana-container]] - Home-built container image
- [[kustomize-grafana-deployment]] - Kustomize manifest structure
- [[authentik]] - OIDC identity provider for SSO
- [[prometheus]] - Metrics datasource
- [[loki]] - Logs datasource
- [[alloy|Alloy]] - Data collector
