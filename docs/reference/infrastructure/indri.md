---
title: indri
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
- [[forgejo]] - Git forge
- [[zot]] - Container registry
- [[jellyfin]] - Media server
- [[borgmatic]] - Backup system
- [[grafana-alloy|Alloy]] - Metrics/logs collector
- Caddy - Reverse proxy for `*.ops.eblu.me`

**Kubernetes (via minikube):**
- [[argocd-applications|All k8s applications]]

## Related

- [[service-routing|Routing]] - Port mappings
- [[kubernetes-cluster|Cluster]] - Minikube details
