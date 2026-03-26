---
title: Observability
modified: 2026-03-26
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

## Future: Continuous Profiling (Pyroscope)

Full implementation on branch `preserve/pyroscope-profiling/pr-313` (PR #313, closed). Includes Pyroscope server (StatefulSet on ringtail), Alloy profiling DaemonSet (`pyroscope.ebpf`), Grafana datasource with traces-to-profiles linking, Nix container build with embedded frontend, and documentation.

**Blocked on ringtail kernel sysctl settings.** The `pyroscope.ebpf` Alloy component requires:
- `kernel.kptr_restrict = 0` (currently `1` — kallsyms addresses are zeroed)
- `kernel.perf_event_paranoid ≤ 1` (currently `2` — eBPF perf events restricted)

These must be set in ringtail's NixOS configuration (`boot.kernel.sysctl`). Once applied, the branch can be rebased onto main and deployed.

## Future: Frontend Monitoring (RUM)

Grafana Faro is a Real User Monitoring SDK that captures page loads, web vitals, errors, and network timings from the browser, feeding into Loki (logs) and Tempo (traces) via Alloy's `faro.receiver` component. This would add an "outside-in" view of service health from the user's perspective.

**Not currently deployed.** RUM captures browsing behavior from visitors to public services, creating a data retention liability. Would require careful sanitization before deploying.

## Alerting

- [[deploy-infra-alerting]] - Alerting pipeline (Grafana Unified Alerting → ntfy)
- [[runbook-service-probe-failure]] - Service health check failure runbook
- [[runbook-postgres-unhealthy]] - PostgreSQL cluster health runbook
- [[runbook-pod-not-ready]] - Pod not ready runbook
- [[runbook-textfile-stale]] - Metrics textfile freshness runbook
- [[runbook-frigate-camera-down]] - Frigate camera health runbook
- [[runbook-argocd-out-of-sync]] - ArgoCD sync status runbook
