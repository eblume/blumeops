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
- [[Forgejo]] - Git forge
- [[Zot]] - Container registry
- [[Jellyfin]] - Media server
- [[Borgmatic]] - Backup system
- [[Grafana Alloy|Alloy]] - Metrics/logs collector
- Caddy - Reverse proxy for `*.ops.eblu.me`

**Kubernetes (via minikube):**
- [[ArgoCD Applications|All k8s applications]]

## Related

- [[Service Routing|Routing]] - Port mappings
- [[Kubernetes Cluster|Cluster]] - Minikube details
