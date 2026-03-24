---
title: Deploy Prowler CIS Scanner
modified: 2026-03-24
last-reviewed: 2026-03-24
tags:
  - how-to
  - kubernetes
  - security
  - compliance
---

# Deploy Prowler CIS Scanner

Prowler runs weekly CIS Kubernetes Benchmark scans against minikube-indri and writes HTML/CSV/JSON reports to the NFS share on sifaka.

## What it checks

Prowler's Kubernetes provider runs ~70 checks from the CIS Kubernetes Benchmark v1.11, grouped into:

| Category | Checks | How it works |
|----------|--------|-------------|
| **Core (pod security)** | 13 | Queries K8s API for privileged containers, hostPID/hostNetwork, capabilities, secrets in env vars, seccomp |
| **RBAC** | 9 | Queries RBAC API for overprivileged roles, wildcard access, cluster-admin bindings |
| **Apiserver** | 29 | Inspects `kube-apiserver` pod args in kube-system (TLS, auth, audit, admission plugins) |
| **Etcd** | 7 | Inspects `etcd` pod args (TLS, cert auth) |
| **Controller Manager** | 7 | Inspects `kube-controller-manager` pod args |
| **Kubelet** | 16 | Reads kubelet-config ConfigMap + node file permissions (file checks need hostPID) |
| **Scheduler** | 2 | Inspects `kube-scheduler` pod args |

**Minikube relevance:** Most checks work because minikube runs control plane as static pods. Kubelet file permission checks return MANUAL unless Prowler runs on the node (we mount host paths to enable this).

**k3s note:** k3s embeds the control plane in a single binary — no static pods exist. Only core + RBAC checks (~22 of 70) produce results. Consider `kube-bench` for k3s control plane checks.

## Reports

Reports are written to `sifaka:/volume1/reports/prowler/` with timestamped filenames. See [[read-compliance-reports]] for how to access and interpret them.

## Running an ad-hoc scan

```fish
kubectl create job --from=cronjob/prowler prowler-manual -n prowler --context=minikube-indri
```

Watch progress:

```fish
kubectl logs -f job/prowler-manual -n prowler --context=minikube-indri
```

## Container

Custom slim build at `containers/prowler/Dockerfile` — strips PowerShell, Trivy, and non-Kubernetes providers from upstream. See [[build-container-image]] for the build/release process.

Source is mirrored at `forge.ops.eblu.me/mirrors/prowler`.

## See also

- [[security]] — security & compliance posture overview
- [[read-compliance-reports]] — how to access and interpret scan reports
- [[deploy-k8s-service]] — general K8s deployment how-to
- [[build-container-image]] — container build pipeline
