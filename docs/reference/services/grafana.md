---
title: Grafana
modified: 2026-06-09
last-reviewed: 2026-06-09
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
| **Sidecar Image** | `registry.ops.eblu.me/blumeops/grafana-sidecar` |

## Authentication

Grafana supports two login methods:

- **SSO via [[authentik]]** — OIDC login through Authentik (`auth.generic_oauth`). Members of the Authentik `admins` group get the Admin role; everyone else gets Viewer (`role_attribute_path` in `grafana.ini`).
- **Local admin** — break-glass login using the password from 1Password ("Grafana (blumeops)"). Always available if Authentik is down.

The OIDC client secret is injected via [[external-secrets]] (`grafana-authentik-oauth` secret in monitoring namespace).

## Datasources

| Name | Type | Target |
|------|------|--------|
| Prometheus | prometheus | `prometheus.monitoring.svc.cluster.local:9090` |
| Loki | loki | `loki.monitoring.svc.cluster.local:3100` |
| Tempo | tempo | `tempo.monitoring.svc.cluster.local:3200` |
| TeslaMate | postgres | `pg.ops.eblu.me:5434` (TeslaMate's database on [[ringtail]], via Caddy L4) |

## Dashboard Provisioning

Dashboards are ConfigMaps with label `grafana_dashboard: "1"`.

Location: `argocd/manifests/grafana-config/dashboards/`

Optional annotation: `grafana_folder: "FolderName"`

## Key Dashboards

Provisioned dashboards live in `argocd/manifests/grafana-config/dashboards/` (one ConfigMap per dashboard). Coverage as of 2026-06: alerts, borgmatic, CV APM, devpi, docs APM, fly.io proxy, forgejo, frigate, jellyfin, kubernetes, loki, macOS (indri host), postgresql, ringtail, shower APM, sifaka disks, snowflake proxy, tempo, transmission, zot.

TeslaMate's dashboards are not in the repo — an init container fetches them from the forge mirror at a pinned tag (`TESLAMATE_VERSION` in `argocd/manifests/grafana/deployment.yaml`).

## Related

- [[build-grafana-images]] - Home-built container images (Grafana + sidecar)
- [[kustomize-grafana-deployment]] - Kustomize manifest structure
- [[authentik]] - OIDC identity provider for SSO
- [[migrate-grafana-to-authentik]] - How SSO was migrated from Dex to Authentik
- [[prometheus]] - Metrics datasource
- [[loki]] - Logs datasource
- [[tempo]] - Traces datasource
- [[alloy|Alloy]] - Data collector
