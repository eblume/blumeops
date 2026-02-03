---
title: Indri
tags:
  - infrastructure
  - host
---

# Indri

Primary BlumeOps server. Mac Mini M1 (2020).

## Specifications

| Property | Value |
|----------|-------|
| **Model** | Mac mini M1, 2020 (Macmini9,1) |
| **Storage** | 2TB internal SSD |
| **macOS** | 15.7.3 (Sequoia) |
| **Tailscale IP** | 100.98.163.89 |
| **Tailscale Tag** | `tag:homelab` |

## Services Hosted

**Native (via Ansible):**
- [[reference/services/forgejo|Forgejo]] - Git forge
- [[reference/services/zot|Zot]] - Container registry
- [[reference/services/jellyfin|Jellyfin]] - Media server
- [[reference/services/borgmatic|Borgmatic]] - Backup system
- [[reference/services/alloy|Alloy]] - Metrics/logs collector
- Caddy - Reverse proxy for `*.ops.eblu.me`

**Kubernetes (via minikube):**
- [[reference/kubernetes/apps|All k8s applications]]

## Related

- [[reference/infrastructure/routing|Routing]] - Port mappings
- [[reference/kubernetes/cluster|Cluster]] - Minikube details
