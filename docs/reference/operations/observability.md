---
title: Observability
modified: 2026-03-22
tags:
  - operations
---

# Observability

Metrics, logs, traces, and dashboards for BlumeOps infrastructure.

## Components

- [[prometheus]] - Metrics storage and querying
- [[loki]] - Log aggregation
- [[tempo]] - Distributed tracing
- [[alloy|Alloy]] - Metrics, log, and trace collection
- [[grafana]] - Dashboards and visualization

## Alerting

- [[deploy-infra-alerting]] - Alerting pipeline (Grafana Unified Alerting → ntfy)
- [[runbook-service-probe-failure]] - Service health check failure runbook
- [[runbook-postgres-unhealthy]] - PostgreSQL cluster health runbook
- [[runbook-pod-not-ready]] - Pod not ready runbook
- [[runbook-textfile-stale]] - Metrics textfile freshness runbook
- [[runbook-frigate-camera-down]] - Frigate camera health runbook
- [[runbook-argocd-out-of-sync]] - ArgoCD sync status runbook
