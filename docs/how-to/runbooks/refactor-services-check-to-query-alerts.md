---
title: Refactor services-check to Query Alerts
modified: 2026-03-22
last-reviewed: 2026-06-20
tags:
  - how-to
  - alerting
---

# Refactor services-check to Query Alerts

Change `mise run services-check` from doing its own health probes to querying the Grafana alerting API for currently firing alerts. The script becomes a CLI view into the same alerting system that sends ntfy notifications.

## What to Do

### 1. Query the Grafana Alerting API

Grafana exposes alert state via:
- `GET /api/v1/provisioning/alert-rules` — all configured rules
- `GET /api/prometheus/grafana/api/v1/alerts` — currently firing alerts (Prometheus-compatible format)

The second endpoint is simpler — it returns only active alerts with labels and annotations, similar to Alertmanager's `/api/v1/alerts`.

### 2. Rewrite services-check

The new services-check should:
1. Query the Grafana alerting API for firing alerts
2. Display them in a table with service name, alert name, duration, and runbook link
3. If no alerts are firing, print a green "all clear" message
4. Exit 0 if no alerts, exit 1 if any are firing
5. Optionally keep a few checks that don't map to alerting (e.g., the ArgoCD sync status table as a summary view)

### 3. Handle Authentication

services-check will need a Grafana API token or service account token. Options:
- Use the existing Grafana admin credentials from 1Password (`op read`)
- Create a dedicated read-only service account in Grafana

### 4. Preserve the ArgoCD Summary

The ArgoCD sync/health table in services-check is a useful quick view even when nothing is alerting. Consider keeping it as a separate section that always displays, independent of the alert query.

## Verification

- [ ] `mise run services-check` queries Grafana instead of doing direct probes
- [ ] Firing alerts are displayed with service name, alert name, and runbook link
- [ ] Exit code reflects alert state (0 = clear, 1 = firing)
- [ ] Works when Grafana is unreachable (graceful error, not a crash)
- [ ] ArgoCD summary table still works

## Related

- [[port-services-check-alerts]] — Prerequisite: alerts must exist to query
- [[deploy-infra-alerting]] — Parent goal
