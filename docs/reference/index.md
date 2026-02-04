---
title: reference
tags:
  - reference
---

# Reference

Technical specifications, inventories, and configuration details for BlumeOps infrastructure.

## Services

Individual service reference cards with URLs and configuration details.

| Service | Description | Location |
|---------|-------------|----------|
| [[grafana-alloy|Alloy]] | Observability collector (metrics & logs) | indri + k8s |
| [[argocd]] | GitOps continuous delivery | k8s |
| [[borgmatic]] | Backup system | indri |
| [[1password]] | Secrets management | cloud + k8s |
| [[forgejo]] | Git forge & CI/CD | indri |
| [[grafana]] | Dashboards & visualization | k8s |
| [[immich]] | Photo management | k8s |
| [[jellyfin]] | Media server | indri |
| [[kiwix]] | Offline Wikipedia & ZIM archives | k8s |
| [[loki]] | Log aggregation | k8s |
| [[miniflux]] | RSS feed reader | k8s |
| [[navidrome]] | Music streaming | k8s |
| [[postgresql]] | Database cluster | k8s |
| [[prometheus]] | Metrics collection | k8s |
| [[teslamate]] | Tesla data logger | k8s |
| [[transmission]] | BitTorrent daemon | k8s |
| [[zot]] | Container registry | indri |

## Infrastructure

Host inventory and network configuration.

- [[host-inventory|Hosts]] - Device inventory
- [[indri]] - Primary server
- [[gilbert]] - Development workstation
- [[tailscale]] - ACLs, groups, tags
- [[service-routing|Routing]] - DNS domains, port mappings

## Kubernetes

Cluster configuration and application registry.

- [[kubernetes-cluster|Cluster]] - Minikube specs, storage, networking
- [[argocd-applications|Apps]] - ArgoCD application registry
- [[external-secrets]] - Secrets management

## Storage

Network storage and backup configuration.

- [[sifaka-nas|Sifaka]] - Synology NAS configuration
- [[postgresql-storage]] - Database cluster
- [[backup-policy|Backups]] - Backup policy and schedule

## Operations

Operational concerns and their components.

- [[observability]] - Metrics, logs, dashboards
- [[backup]] - Data protection
- [[disaster-recovery]] - Recovery procedures (TBD)
