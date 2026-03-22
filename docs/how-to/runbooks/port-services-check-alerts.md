---
title: Port services-check Alerts to Grafana
modified: 2026-03-22
tags:
  - how-to
  - alerting
---

# Port services-check Alerts to Grafana

Systematically migrate the health checks from `mise run services-check` to Grafana alert rules, each with a corresponding runbook. After this card, the alerting system covers everything services-check does today.

## What to Do

### 1. Inventory and Prioritize

Map each services-check probe to a data source and alert rule. Some checks already have metrics in Prometheus; others need new instrumentation.

**Already have metrics (easy):**
- HTTP endpoint probes → Alloy blackbox exporter (`probe_success`)
- PostgreSQL health → CNPG metrics (`cnpg_pg_replication_streaming`, `cnpg_collector_up`)
- K8s pod health → kube-state-metrics (`kube_pod_status_phase`)
- ArgoCD sync status → ArgoCD metrics (`argocd_app_info` with sync/health labels)

**Need new probes or metrics:**
- Local indri services (forgejo, alloy, borgmatic, zot via brew/launchctl) → Alloy host textfile or new probes
- Metrics textfile freshness → `node_textfile_mtime_seconds` (already collected by Alloy on indri)
- Ringtail SSH/tailscale health → Alloy blackbox on ringtail or cross-cluster probe
- Public services (docs, cv, forge via Fly.io) → Alloy on Fly.io or Grafana synthetic monitoring

### 2. Add Missing Probes

Extend Alloy configurations where needed:
- **Alloy on indri:** Add blackbox targets for forgejo, zot (local HTTP endpoints)
- **Alloy on ringtail:** Add blackbox targets for ringtail-local services
- **Consider:** Whether public endpoint probing belongs in Fly.io Alloy or a separate prober

### 3. Create Alert Rules

For each check category, create provisioned Grafana alert rules. Group related checks into alert rule groups (e.g., "indri-services", "k8s-health", "public-endpoints").

### 4. Create Runbooks

One runbook per alert type in `docs/how-to/runbooks/runbook-<name>.md`. Each runbook should cover:
- What the alert means
- Diagnostic steps
- Common fixes
- How to silence for planned maintenance

### 5. Remove from services-check

As each check is ported, remove it from the services-check script (or mark it as "now handled by alerting"). The goal is that services-check shrinks as alerting grows.

## Key Details

- Don't try to port everything in one session — this card may span multiple work cycles within the C2 chain
- Prioritize checks that have caught real problems in the past
- Some checks (like ArgoCD sync status table) may remain in services-check as a human-readable summary even after alerting covers the failure cases
- The Alloy blackbox exporter on k8s already covers 5 services; extending it to more is straightforward

## Verification

- [ ] All HTTP endpoint checks from services-check have corresponding alert rules
- [ ] Pod health checks have corresponding alert rules
- [ ] PostgreSQL health has a corresponding alert rule
- [ ] Each alert rule has a runbook doc in `docs/how-to/runbooks/`
- [ ] Test at least 2-3 failure scenarios end-to-end
- [ ] services-check script has been updated to reflect ported checks

## Related

- [[first-alert-and-runbook]] — Prerequisite: established the pattern
- [[deploy-infra-alerting]] — Parent goal
- [[refactor-services-check-to-query-alerts]] — Next: make services-check query alerts
