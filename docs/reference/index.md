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
| [[services/alloy|Alloy]] | Observability collector (metrics & logs) | indri + k8s |
| [[services/argocd|ArgoCD]] | GitOps continuous delivery | k8s |
| [[services/borgmatic|Borgmatic]] | Backup system | indri |
| [[services/1password|1Password]] | Secrets management | cloud + k8s |
| [[services/forgejo|Forgejo]] | Git forge & CI/CD | indri |
| [[services/grafana|Grafana]] | Dashboards & visualization | k8s |
| [[services/immich|Immich]] | Photo management | k8s |
| [[services/jellyfin|Jellyfin]] | Media server | indri |
| [[services/kiwix|Kiwix]] | Offline Wikipedia & ZIM archives | k8s |
| [[services/loki|Loki]] | Log aggregation | k8s |
| [[services/miniflux|Miniflux]] | RSS feed reader | k8s |
| [[services/navidrome|Navidrome]] | Music streaming | k8s |
| [[services/postgresql|PostgreSQL]] | Database cluster | k8s |
| [[services/prometheus|Prometheus]] | Metrics collection | k8s |
| [[services/teslamate|TeslaMate]] | Tesla data logger | k8s |
| [[services/transmission|Transmission]] | BitTorrent daemon | k8s |
| [[services/zot|Zot]] | Container registry | indri |

## Infrastructure

Host inventory and network configuration.

- [[infrastructure/hosts|Hosts]] - Device inventory
- [[infrastructure/indri|Indri]] - Primary server
- [[infrastructure/gilbert|Gilbert]] - Development workstation
- [[infrastructure/tailscale|Tailscale]] - ACLs, groups, tags
- [[infrastructure/routing|Routing]] - DNS domains, port mappings

## Kubernetes

Cluster configuration and application registry.

- [[kubernetes/cluster|Cluster]] - Minikube specs, storage, networking
- [[kubernetes/apps|Apps]] - ArgoCD application registry
- [[kubernetes/external-secrets|External Secrets]] - Secrets management

## Storage

Network storage and backup configuration.

- [[storage/sifaka|Sifaka]] - Synology NAS configuration
- [[storage/postgresql|PostgreSQL]] - Database cluster
- [[storage/backups|Backups]] - Backup policy and schedule

## Operations

Operational concerns and their components.

- [[operations/observability|Observability]] - Metrics, logs, dashboards
- [[operations/backup|Backup]] - Data protection
- [[operations/disaster-recovery|Disaster Recovery]] - Recovery procedures (TBD)
