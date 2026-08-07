---
title: "Runbook: Pod Not Ready"
modified: 2026-08-06
last-reviewed: 2026-08-06
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Pod Not Ready

**Alert name:** `PodNotReady`

A Kubernetes pod has been in a not-ready state for 5+ minutes.

## Diagnostic Steps

1. **Identify the pod** from the alert labels (`pod`, `namespace`):
   ```fish
   kubectl describe pod <pod> -n <namespace> --context=k3s-ringtail
   ```

2. **Check events** — look for scheduling failures, image pull errors, or probe failures:
   ```fish
   kubectl get events -n <namespace> --context=k3s-ringtail --sort-by='.lastTimestamp' | tail -20
   ```

3. **Check logs**:
   ```fish
   kubectl logs <pod> -n <namespace> --context=k3s-ringtail --tail=50
   ```

4. **Check whether the pod can be scheduled.** `kubectl top` does **not** work
   here — ringtail's k3s runs with `--disable=metrics-server`, so the Metrics
   API does not exist and `kubectl top` errors out.

   No loss for this alert. `kubectl top` reports live *utilization*, but a
   `Pending` pod is a question about *requests versus allocatable* — the
   scheduler does not care what is currently in use. Ask Prometheus instead
   (Grafana → Explore → Prometheus):

   ```promql
   # What the node has to give
   kube_node_status_allocatable{cluster="ringtail", resource=~"cpu|memory"}

   # What is already claimed on it
   sum by (resource) (kube_pod_container_resource_requests{cluster="ringtail"})

   # Free memory on the box, for the OOM-pressure case
   node_memory_MemAvailable_bytes{cluster="ringtail"}

   # Which pods are not Running, and what the alert itself sees
   kube_pod_status_phase{phase!="Running"} > 0
   kube_pod_status_ready{condition="false"} > 0
   ```

   There is no cAdvisor scrape either, so per-container live usage
   (`container_memory_working_set_bytes`) is unavailable. If you genuinely need
   live numbers, `kubectl describe node` prints the allocated-resources table
   without touching the Metrics API.

## Common Causes

- **CrashLoopBackOff** — app is crashing on startup, check logs
- **ImagePullBackOff** — container image not found or registry unreachable
- **Pending** — insufficient resources (CPU/memory), or PVC not bound
- **Readiness probe failing** — service is running but not healthy
- **NFS mount issue** — services depending on sifaka (kiwix, transmission, navidrome, jellyfin) will fail if NFS is down

## Silencing

1. Grafana → Alerting → Silences → Create Silence
2. Match `alertname = PodNotReady`
3. Optionally match `namespace = <namespace>` to silence a specific service

## Related

- [[deploy-infra-alerting]] — Alerting pipeline overview
- [[ringtail]] — the k3s node, including which built-in components are disabled
- [[observability]] — where the Prometheus queries above come from
