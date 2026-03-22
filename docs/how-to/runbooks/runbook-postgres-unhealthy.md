---
title: "Runbook: PostgreSQL Cluster Unhealthy"
modified: 2026-03-22
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: PostgreSQL Cluster Unhealthy

**Alert name:** `PostgresClusterUnhealthy`

The CNPG collector metrics endpoint is down, indicating the PostgreSQL cluster is not responding.

## Affected Services

The `blumeops-pg` CNPG cluster on indri's minikube runs databases for:
- TeslaMate
- Authentik (cross-cluster from ringtail)
- Immich
- Grafana dashboards (TeslaMate datasource)

## Diagnostic Steps

1. **Check CNPG cluster status**:
   ```fish
   kubectl get cluster blumeops-pg -n databases --context=minikube-indri
   kubectl get pods -n databases -l cnpg.io/cluster=blumeops-pg --context=minikube-indri
   ```

2. **Check pod logs**:
   ```fish
   kubectl logs -n databases -l cnpg.io/cluster=blumeops-pg --context=minikube-indri --tail=30
   ```

3. **Check if pg_isready**:
   ```fish
   pg_isready -h pg.ops.eblu.me -p 5432
   ```

4. **Check PVC storage**:
   ```fish
   kubectl get pvc -n databases --context=minikube-indri
   ```

## Common Causes

- **Pod crash** — OOM, disk full, or configuration error
- **PVC storage full** — check with `kubectl exec` into the pod and `df -h`
- **Minikube issue** — if the node is under memory pressure, CNPG pods may be evicted
- **Network** — Caddy L4 proxy (`pg.ops.eblu.me`) may be misconfigured

## Silencing

For planned database maintenance:
1. Grafana → Alerting → Silences → Create Silence
2. Match `alertname = PostgresClusterUnhealthy`

## Related

- [[postgresql]] — CNPG cluster reference
- [[deploy-infra-alerting]] — Alerting pipeline overview
