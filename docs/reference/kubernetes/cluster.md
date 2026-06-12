---
title: Cluster
modified: 2026-06-11
last-reviewed: 2026-06-11
tags:
  - kubernetes
---

# Kubernetes Cluster

BlumeOps runs a single Kubernetes cluster: k3s on [[ringtail]], managed
by [[argocd]] running in-cluster. (Until 2026-06 a minikube cluster on
[[indri]] hosted most services — retired in [[retire-minikube]].)

## Cluster Specifications

| Property | Value |
|----------|-------|
| **Distribution** | k3s (single node) |
| **Context** | `k3s-ringtail` |
| **API Server** | `https://ringtail.tail8d86e.ts.net:6443` |
| **Architecture** | x86_64, RTX 4080 GPU |

See [[ringtail]] for host specs, the workload list, and secrets
management.

## Volume Mounting

Stateful workloads use the `local-path` storage class (node-local).
Media and bulk data mount NFS directly from [[sifaka|Sifaka]] — see
[[sifaka-nfs-from-ringtail]].

## Images

Workload images are locally built (Nix, amd64, `-nix` tags) and pulled
from [[zot]] at `registry.ops.eblu.me`. A handful of infrastructure
images (argocd, cnpg, external-secrets, 1password-connect) remain
pinned upstream multi-arch — tracked by the local-registry compliance
task.

## Related

- [[apps|Apps]] - ArgoCD applications
- [[argocd]] - GitOps deployment
- [[zot]] - Registry
- [[ringtail]] - Host reference
