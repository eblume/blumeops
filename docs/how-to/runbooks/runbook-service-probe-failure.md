---
title: "Runbook: Service Probe Failure"
modified: 2026-03-22
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Service Probe Failure

**Alert name:** `ServiceProbeFailure`

A blackbox HTTP health check has failed for 2+ minutes, meaning a service is not responding to its health endpoint.

## Affected Services

This alert covers services probed by the Alloy blackbox exporter on indri's minikube cluster:

| Service | Health Endpoint |
|---------|----------------|
| miniflux | `/healthcheck` |
| kiwix | `/` |
| transmission | `/transmission/web/` |
| devpi | `/+api` |
| argocd | `/healthz` |

The failing service is identified by the `service` label in the alert (extracted from the `job` label).

## Diagnostic Steps

1. **Check which service is down** — the alert label `service` tells you. You can also run:
   ```fish
   kubectl get pods -n <namespace> --context=minikube-indri
   ```

2. **Check pod status** — look for CrashLoopBackOff, OOMKilled, or pending pods:
   ```fish
   kubectl describe pod -n <namespace> <pod-name> --context=minikube-indri
   ```

3. **Check pod logs**:
   ```fish
   kubectl logs -n <namespace> <pod-name> --context=minikube-indri --tail=50
   ```

4. **Check if minikube itself is healthy**:
   ```fish
   ssh indri 'minikube status'
   ```

5. **Check NFS mounts** (kiwix, transmission depend on sifaka NFS):
   ```fish
   ssh indri 'df -h | grep Volumes'
   ```

## Common Causes

- **Pod crashed** — check logs, restart with `kubectl delete pod`
- **NFS mount lost** — sifaka offline or AutoMounter not running. SSH to indri and check `/Volumes/`
- **Resource exhaustion** — check `kubectl top pods -n <namespace>` for memory/CPU pressure
- **Minikube paused/stopped** — `ssh indri 'minikube status'`, restart if needed

## Silencing

For planned maintenance, silence this alert in Grafana:
1. Go to Alerting → Silences → Create Silence
2. Match label `alertname = ServiceProbeFailure`
3. Optionally match `service = <specific-service>` to silence only one
4. Set duration for your maintenance window

## Related

- [[deploy-infra-alerting]] — Alerting pipeline overview
- [[configure-grafana-alerting-pipeline]] — Pipeline configuration
