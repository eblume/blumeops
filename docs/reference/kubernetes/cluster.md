---
title: Cluster
modified: 2026-02-19
tags:
  - kubernetes
---

# Kubernetes Cluster

BlumeOps runs two Kubernetes clusters: a Minikube cluster on [[indri]] (most services) and a k3s cluster on [[ringtail]] (GPU workloads, MQTT, notifications). Both are managed by [[argocd]] on indri.

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

Pods mount NFS directly from [[sifaka|Sifaka]]. Docker NATs outbound traffic through indri's LAN IP (192.168.1.50), allowing access to Sifaka's NFS exports.

## Registry Mirror

Containerd uses [[zot]] as a pull-through cache at `host.minikube.internal:5050`.

Mirrors configured: `registry.ops.eblu.me`, `docker.io`, `ghcr.io`, `quay.io`

## K3s on Ringtail

Single-node k3s cluster for workloads requiring amd64 or GPU access. See [[ringtail]] for cluster specs, workload list, and secrets management.

| Property | Value |
|----------|-------|
| **Context** | `k3s-ringtail` |
| **API Server** | `https://ringtail.tail8d86e.ts.net:6443` |
| **Workloads** | Frigate (GPU), Mosquitto, ntfy, frigate-notify, nvidia-device-plugin |

## Related

- [[apps|Apps]] - ArgoCD applications
- [[argocd]] - GitOps deployment
- [[zot]] - Registry mirror
