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
| [[alloy|Alloy]] | Observability collector (metrics & logs) | indri + k8s |
| [[argocd|ArgoCD]] | GitOps continuous delivery | k8s |
| [[borgmatic|Borgmatic]] | Backup system | indri |
| [[1password|1Password]] | Secrets management | cloud + k8s |
| [[forgejo|Forgejo]] | Git forge & CI/CD | indri |
| [[grafana|Grafana]] | Dashboards & visualization | k8s |
| [[immich|Immich]] | Photo management | k8s |
| [[jellyfin|Jellyfin]] | Media server | indri |
| [[kiwix|Kiwix]] | Offline Wikipedia & ZIM archives | k8s |
| [[loki|Loki]] | Log aggregation | k8s |
| [[miniflux|Miniflux]] | RSS feed reader | k8s |
| [[navidrome|Navidrome]] | Music streaming | k8s |
| [[postgresql|PostgreSQL]] | Database cluster | k8s |
| [[prometheus|Prometheus]] | Metrics collection | k8s |
| [[teslamate|TeslaMate]] | Tesla data logger | k8s |
| [[transmission|Transmission]] | BitTorrent daemon | k8s |
| [[zot|Zot]] | Container registry | indri |

## Infrastructure

Host inventory and network configuration.

- [[hosts|Hosts]] - Device inventory
- [[indri|Indri]] - Primary server
- [[gilbert|Gilbert]] - Development workstation
- [[tailscale|Tailscale]] - ACLs, groups, tags
- [[routing|Routing]] - DNS domains, port mappings

## Kubernetes

Cluster configuration and application registry.

- [[cluster|Cluster]] - Minikube specs, storage, networking
- [[apps|Apps]] - ArgoCD application registry
- [[external-secrets|External Secrets]] - Secrets management

## Storage

Network storage and backup configuration.

- [[sifaka|Sifaka]] - Synology NAS configuration
- [[postgresql-storage|PostgreSQL Storage]] - Database cluster
- [[backups|Backups]] - Backup policy and schedule

## Operations

Operational concerns and their components.

- [[observability|Observability]] - Metrics, logs, dashboards
- [[backup|Backup]] - Data protection
- [[disaster-recovery|Disaster Recovery]] - Recovery procedures (TBD)
