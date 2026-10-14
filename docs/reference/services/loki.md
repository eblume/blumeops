---
title: Loki
modified: 2026-10-14
last-reviewed: 2026-10-14
tags:
  - service
  - observability
---

# Loki

Log aggregation system for BlumeOps infrastructure.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://loki.ops.eblu.me |
| **Namespace** | `monitoring` |
| **Deployment** | Kustomize (`argocd/manifests/loki-ringtail/`) |
| **Image** | `registry.ops.eblu.me/blumeops/loki` (see `argocd/manifests/loki-ringtail/kustomization.yaml` for current tag) |
| **Storage** | 20Gi PVC |
| **Retention** | 365 days |

## Architecture

- Single-node StatefulSet on [[ringtail]]'s k3s with filesystem storage (migrated off minikube — see [[retire-minikube]])
- TSDB index with 24h period
- Logs collected by [[alloy|Alloy]] and pushed via Loki API
- Queried via [[grafana]]

## Log Sources

**From Indri (via Alloy):**
- tailscale (brew service log)
- forgejo, alloy, netconsole, borgmatic, borgmatic-ops, borgmatic-photos, borgmatic-verify-photos, zot, jellyfin, forgejo-runner, runner-cache-sweep, caddy, heph, devpi (mcquack LaunchAgents; netconsole also carries the ringtail kernel crash capture)

**From Kubernetes (via Alloy DaemonSet on ringtail):**
- All pods in all namespaces

**From Fly.io proxy (via embedded Alloy):**
- nginx JSON access logs (`{instance="flyio-proxy", job="flyio-nginx"}`)

## Query Examples (LogQL)

```logql
{service="forgejo"}                     # All forgejo logs
{service="borgmatic", stream="stderr"}  # Borgmatic errors
{host="indri"} |= "error"               # All logs containing "error"
{instance="flyio-proxy"} |= "docs.eblu.me" # Fly.io proxy access logs for docs
```

## Related

- [[alloy|Alloy]] - Log collector
- [[grafana]] - Log visualization
- [[prometheus]] - Metrics counterpart
- [[retire-minikube]] - The migration that moved Loki from minikube to ringtail
