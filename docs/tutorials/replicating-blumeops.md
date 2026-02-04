---
title: replicating-blumeops
tags:
  - tutorials
  - replication
---

# Replicating BlumeOps

> **Audiences:** Replicator

This tutorial provides a roadmap for building your own homelab GitOps environment inspired by BluemeOps. It links to detailed component tutorials for each major piece.

## What You'll Build

By following this guide, you'll have:
- A secure mesh network connecting your devices
- A Kubernetes cluster for running containerized services
- GitOps-driven deployments via ArgoCD
- Observability with metrics, logs, and dashboards
- Backup and disaster recovery capabilities

## Hardware Requirements

BluemeOps runs on modest hardware. At minimum:

| Component | BlumeOps Uses | Minimum Alternative |
|-----------|---------------|---------------------|
| **Server** | Mac Mini M1 | Any machine with sufficient RAM (16GB recommended) |
| **NAS** | Synology DS920+ | USB drive or second machine |
| **Workstation** | MacBook Air M4 | Whatever you use daily |

You can start with a single machine and add storage later.

## The Journey

### Phase 1: Networking Foundation

Before deploying services, establish secure connectivity.

**[[tutorials/replication/tailscale-setup|Setting Up Tailscale]]**
- Create a tailnet and connect your devices
- Configure ACLs for service access
- Set up MagicDNS for convenient naming

This replaces: traditional VPNs, port forwarding, dynamic DNS

### Phase 2: Core Services

Bootstrap the essential services that everything else depends on.

**[[tutorials/replication/core-services | Core Services Setup]]**
- Set up [[forgejo]] for git hosting and CI/CD
- Optionally set up [[zot]] container registry
- Configure SSH access and deploy keys

Forgejo is central to GitOps - it's where your infrastructure definitions live and where CI/CD workflows run.

### Phase 3: Kubernetes Cluster

A cluster for running containerized workloads.

**[[tutorials/replication/kubernetes-bootstrap|Bootstrapping Kubernetes]]**
- Install minikube (or k3s, kind, etc.)
- Configure persistent storage
- Expose the API securely via Tailscale

BlumeOps uses minikube for simplicity, but the patterns apply to any distribution.

### Phase 4: GitOps with ArgoCD

Declarative, git-driven deployments.

**[[tutorials/replication/argocd-config|Configuring ArgoCD]]**
- Install ArgoCD in your cluster
- Connect to your git repository
- Deploy your first application
- Set up the app-of-apps pattern

This is the heart of GitOps - changes in git automatically sync to your cluster.

### Phase 5: Observability Stack

Know what's happening in your infrastructure.

**[[tutorials/replication/observability-stack|Building the Observability Stack]]**
- Deploy Prometheus for metrics
- Deploy Loki for logs
- Deploy Grafana for dashboards
- Configure Alloy for collection

Without observability, you're flying blind.

### Phase 6: Your First Services

With the foundation in place, deploy actual workloads. BluemeOps runs:
- [[miniflux]] - RSS reader
- [[jellyfin]] - Media server
- [[immich]] - Photo management
- [[navidrome]] - Music streaming
- [[docs]] - Documentation site (Quartz)

Pick what matters to you. Each service follows similar patterns:
1. Create Kubernetes manifests
2. Create ArgoCD Application
3. Configure ingress routing
4. Sync and verify

### Phase 7: Backups and Resilience

Protect your data.

- Set up [[borgmatic]] for backup automation
- Configure NAS as backup target
- Test restore procedures
- Document disaster recovery

## Alternative Approaches

BluemeOps makes specific choices that may not suit everyone:

| BlumeOps Choice | Alternative |
|-----------------|-------------|
| macOS server | Linux server (more common) |
| Minikube | k3s, kind, or managed K8s |
| Tailscale | WireGuard, Nebula |
| ArgoCD | Flux, manual kubectl |
| Ansible | NixOS, Docker Compose |

The principles (GitOps, IaC, observability) matter more than specific tools.

## Getting Started

Begin with [[tutorials/replication/tailscale-setup]] - networking is the foundation everything else builds on.

## Related

- [[reference/index]] - See BlumeOps' specific configurations
- [[contributing]] - Help improve BlumeOps instead
