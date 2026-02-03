---
title: Reference
tags:
  - reference
---

# Reference

Technical specifications, inventories, and configuration details for BlumeOps infrastructure.

## Services

Individual service reference cards with URLs and configuration details.

| Service | Description | Location |
|---------|-------------|----------|
| [[reference/services/alloy|Alloy]] | Observability collector (metrics & logs) | indri + k8s |
| [[reference/services/argocd|ArgoCD]] | GitOps continuous delivery | k8s |
| [[reference/services/borgmatic|Borgmatic]] | Backup system | indri |
| [[reference/services/1password|1Password]] | Secrets management | cloud + k8s |
| [[reference/services/forgejo|Forgejo]] | Git forge & CI/CD | indri |
| [[reference/services/grafana|Grafana]] | Dashboards & visualization | k8s |
| [[reference/services/immich|Immich]] | Photo management | k8s |
| [[reference/services/jellyfin|Jellyfin]] | Media server | indri |
| [[reference/services/kiwix|Kiwix]] | Offline Wikipedia & ZIM archives | k8s |
| [[reference/services/loki|Loki]] | Log aggregation | k8s |
| [[reference/services/miniflux|Miniflux]] | RSS feed reader | k8s |
| [[reference/services/navidrome|Navidrome]] | Music streaming | k8s |
| [[reference/services/postgresql|PostgreSQL]] | Database cluster | k8s |
| [[reference/services/prometheus|Prometheus]] | Metrics collection | k8s |
| [[reference/services/teslamate|TeslaMate]] | Tesla data logger | k8s |
| [[reference/services/transmission|Transmission]] | BitTorrent daemon | k8s |
| [[reference/services/zot|Zot]] | Container registry | indri |

## Infrastructure

Host inventory and network configuration.

- [[reference/infrastructure/hosts|Hosts]] - Device inventory
- [[reference/infrastructure/indri|Indri]] - Primary server
- [[reference/infrastructure/gilbert|Gilbert]] - Development workstation
- [[reference/infrastructure/tailscale|Tailscale]] - ACLs, groups, tags
- [[reference/infrastructure/routing|Routing]] - DNS domains, port mappings

## Kubernetes

Cluster configuration and application registry.

- [[reference/kubernetes/cluster|Cluster]] - Minikube specs, storage, networking
- [[reference/kubernetes/apps|Apps]] - ArgoCD application registry
- [[reference/kubernetes/external-secrets|External Secrets]] - Secrets management

## Storage

Network storage and backup configuration.

- [[reference/storage/sifaka|Sifaka]] - Synology NAS configuration
- [[reference/storage/postgresql|PostgreSQL]] - Database cluster
- [[reference/storage/backups|Backups]] - Backup policy and schedule

## Operations

Operational concerns and their components.

- [[reference/operations/observability|Observability]] - Metrics, logs, dashboards
- [[reference/operations/backup|Backup]] - Data protection
- [[reference/operations/disaster-recovery|Disaster Recovery]] - Recovery procedures (TBD)
