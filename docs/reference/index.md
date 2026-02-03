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
| [[Grafana Alloy|Alloy]] | Observability collector (metrics & logs) | indri + k8s |
| [[ArgoCD]] | GitOps continuous delivery | k8s |
| [[Borgmatic]] | Backup system | indri |
| [[1Password]] | Secrets management | cloud + k8s |
| [[Forgejo]] | Git forge & CI/CD | indri |
| [[Grafana]] | Dashboards & visualization | k8s |
| [[Immich]] | Photo management | k8s |
| [[Jellyfin]] | Media server | indri |
| [[Kiwix]] | Offline Wikipedia & ZIM archives | k8s |
| [[Loki]] | Log aggregation | k8s |
| [[Miniflux]] | RSS feed reader | k8s |
| [[Navidrome]] | Music streaming | k8s |
| [[PostgreSQL]] | Database cluster | k8s |
| [[Prometheus]] | Metrics collection | k8s |
| [[TeslaMate]] | Tesla data logger | k8s |
| [[Transmission]] | BitTorrent daemon | k8s |
| [[Zot]] | Container registry | indri |

## Infrastructure

Host inventory and network configuration.

- [[Host Inventory|Hosts]] - Device inventory
- [[Indri]] - Primary server
- [[Gilbert]] - Development workstation
- [[Tailscale]] - ACLs, groups, tags
- [[Service Routing|Routing]] - DNS domains, port mappings

## Kubernetes

Cluster configuration and application registry.

- [[Kubernetes Cluster|Cluster]] - Minikube specs, storage, networking
- [[ArgoCD Applications|Apps]] - ArgoCD application registry
- [[External Secrets]] - Secrets management

## Storage

Network storage and backup configuration.

- [[Sifaka NAS|Sifaka]] - Synology NAS configuration
- [[PostgreSQL Storage]] - Database cluster
- [[Backup Policy|Backups]] - Backup policy and schedule

## Operations

Operational concerns and their components.

- [[Observability]] - Metrics, logs, dashboards
- [[Backup]] - Data protection
- [[Disaster Recovery]] - Recovery procedures (TBD)
