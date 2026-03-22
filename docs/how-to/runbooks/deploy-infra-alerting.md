---
title: Deploy Infrastructure Alerting Pipeline
modified: 2026-03-22
tags:
  - how-to
  - alerting
  - observability
---

# Deploy Infrastructure Alerting Pipeline

Replace the manual `mise run services-check` approach with Grafana Unified Alerting backed by ntfy push notifications, so infrastructure problems page once and include actionable runbook links.

## Architecture

```
Prometheus (metrics) ──┐
                       ├──▶ Grafana Alert Rules ──▶ ntfy webhook ──▶ iOS push
Loki (logs) ──────────┘          │
                                 │
                          Notification Policy
                          (group_wait: 1m,
                           group_interval: 12h,
                           repeat_interval: 24h)
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Alert engine** | Grafana Unified Alerting | Already deployed, no new service needed |
| **Notification** | ntfy webhook contact point | Already deployed on ringtail, iOS app works |
| **Anti-noise** | 24h repeat interval | Page once per day max per alert group |
| **Runbooks** | `docs/how-to/runbooks/<name>.md` | Clickable link in every notification |
| **Provisioning** | Grafana provisioning YAML (GitOps) | Alerts defined in repo, not just UI |
| **Topic** | `infra-alerts` (separate from `frigate-alerts`) | Different severity/audience |

## Alerting Policy

- Each alert fires **once** and does not re-notify for 24 hours
- A "resolved" notification is sent when the condition clears
- Every alert annotation includes `runbook_url` linking to its how-to doc
- The ntfy message template renders the runbook URL as a clickable action button
- Alerts are grouped by service to avoid notification storms

## Migration Path

1. Stand up the pipeline: Grafana alerting config, ntfy contact point, notification policy, message template
2. Create the first alert + runbook as proof of concept (e.g., a blackbox probe failure)
3. Port services-check health checks to Grafana alert rules, one by one, each with a runbook
4. Refactor services-check to query the Grafana alerting API instead of doing its own probes

## What services-check Covers Today

These checks will be migrated to alert rules:

| Category | Checks | Data Source |
|----------|--------|-------------|
| Local services (indri) | forgejo, alloy, borgmatic, zot via brew/launchctl | Need new probes or textfile metrics |
| Metrics textfiles | freshness of `.prom` files | Existing node_textfile metrics |
| K8s cluster health | minikube API, k3s API | kube-state-metrics |
| HTTP endpoints | ~12 services via Caddy | Alloy blackbox exporter (already exists) |
| Ringtail | SSH, tailscale, k3s health | Need new probes |
| K3s pods | ntfy, authentik, frigate, etc. | kube-state-metrics on ringtail |
| Public services | docs, cv, forge via Fly.io | Alloy on Fly.io or external probe |
| PostgreSQL | CNPG readiness | CNPG metrics (already scraped) |
| ArgoCD sync | app sync/health status | ArgoCD metrics or API |

## Related

- [[configure-grafana-alerting-pipeline]] — Foundation: contact point, policy, template
- [[first-alert-and-runbook]] — Proof of concept alert
- [[port-services-check-alerts]] — Systematic migration
- [[refactor-services-check-to-query-alerts]] — Final integration
- [[observability]] — Current observability stack
- [[ntfy]] — Push notification service
- [[grafana]] — Dashboard and alerting platform
