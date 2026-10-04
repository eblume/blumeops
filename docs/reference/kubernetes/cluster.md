---
title: Cluster
modified: 2026-10-03
last-reviewed: 2026-10-03
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

## k3s Manifests

Ringtail declares **no** `services.k3s.manifests`, `autoDeployCharts` or
`charts`. An assertion in `nixos/ringtail` enforces this; lifting it is a
deliberate decision, and if you do, read this section first.

The NixOS k3s module links declared manifests into
`/var/lib/rancher/k3s/server/manifests/` and k3s applies whatever is there.
The module's own caveat applies: *"deleting manifest files will not remove or
otherwise modify the resources it created."* Dropping a manifest from
`nixos/ringtail` therefore does not remove the symlink — the store path stays
alive and k3s's deploy controller keeps re-applying it across rebuilds and
restarts. Seen in the wild: the `coredns-custom` ConfigMap (the in-cluster CoreDNS
rewrite) was removed from code 2026-10-02 and stayed live until it was
cleaned up by hand on 2026-10-03 — the full story is in [[argocd]].

### Removing a manifest (manual cleanup)

1. On ringtail, capture the store path the symlink points at
   (`sudo readlink /var/lib/rancher/k3s/server/manifests/<name>.yaml`), then
   `sudo rm` the symlink.
2. Delete what it created. Prefer `sudo k3s kubectl delete -f <store path>`
   (the path from step 1) to remove the exact objects; otherwise delete the
   specific objects (e.g. `sudo k3s kubectl -n kube-system delete cm <name>`).
3. `sudo k3s kubectl -n kube-system delete addon <name>` so the deploy
   controller stops tracking it. (For a Helm chart in `static/charts/`, the
   analog is deleting the `HelmChart` CR and its release.)
4. If the removed manifest was imported by CoreDNS (a `ConfigMap` in
   `kube-system` referenced from the Corefile), restart CoreDNS:
   `sudo k3s kubectl -n kube-system rollout restart deploy/coredns`.

Verify: `sudo k3s kubectl get addon -n kube-system` and
`sudo k3s kubectl get cm -n kube-system`, and watch
`/var/lib/rancher/k3s/server/manifests/` stay empty of it after a k3s
restart.

## Related

- [[apps|Apps]] - ArgoCD applications
- [[argocd]] - GitOps deployment
- [[zot]] - Registry
- [[ringtail]] - Host reference
