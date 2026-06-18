---
title: "Runbook: Pod Not Ready"
modified: 2026-06-17
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

4. **Check node resources**:
   ```fish
   kubectl top nodes --context=k3s-ringtail
   kubectl top pods -n <namespace> --context=k3s-ringtail
   ```

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
