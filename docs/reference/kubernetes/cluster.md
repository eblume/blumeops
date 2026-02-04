---
title: kubernetes-cluster
tags:
  - kubernetes
---

# Kubernetes Cluster

Single-node Minikube cluster running on [[indri]].

## Cluster Specifications

| Property | Value |
|----------|-------|
| **Driver** | docker |
| **Container Runtime** | docker |
| **Kubernetes Version** | v1.34.0 |
| **CPUs** | 6 |
| **Memory** | 11GB |
| **Disk** | 200GB |
| **API Server** | https://k8s.tail8d86e.ts.net |

**Prerequisites:** Docker Desktop with at least 12GB memory allocated.

## Volume Mounting

Pods mount NFS directly from [[sifaka-nas | Sifaka]]. Docker NATs outbound traffic through indri's LAN IP (192.168.1.50), allowing access to Sifaka's NFS exports.

## Registry Mirror

Containerd uses [[zot]] as a pull-through cache at `host.minikube.internal:5050`.

Mirrors configured: `registry.ops.eblu.me`, `docker.io`, `ghcr.io`, `quay.io`

## Related

- [[argocd-applications | Apps]] - ArgoCD applications
- [[argocd]] - GitOps deployment
- [[zot]] - Registry mirror
