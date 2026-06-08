---
title: Deploy Prowler CIS Scanner
modified: 2026-06-08
last-reviewed: 2026-03-24
tags:
  - how-to
  - kubernetes
  - security
  - compliance
---

# Deploy Prowler CIS Scanner

Prowler runs a weekly CIS Kubernetes Benchmark scan against minikube-indri and writes HTML/CSV/JSON reports to the NFS share on sifaka.

## Why only the K8s CIS scan

Prowler originally ran three CronJobs: K8s CIS, container-image CVE scanning, and IaC scanning. The image and IaC scans were **retired in 2026-06**.

Both were pure toil with no realized value:

- **Image scan** produced ~20,000 unmuted findings per run and growing, none ever triaged or muted. They were overwhelmingly CVEs in *upstream* base images we don't control and can't patch, and the job re-scanned every historical tag still in the registry, multiplying the count.
- **IaC scan** produced ~650 Trivy KSV findings (`runAsNonRoot`, `readOnlyRootFilesystem`, drop-capabilities, …) against our own manifests — real but systemic, homelab-acceptable, and likewise never muted, so the weekly review re-surfaced all of them indefinitely.

The K8s CIS scan, by contrast, is fully mutelisted and runs clean (0 unmuted findings week over week), so it stays. The guiding principle matches [[ai-scraper-mitigation]]: don't keep generating a firehose of output that has no audience. If image-CVE signal is wanted later, the right shape is critical-severity-only, currently-deployed-tags-only, alert-on-new — a rebuild, not a revival (tracked as the "Trivy for image/IaC scanning" task).

Note that the K8s CIS scan itself is tied to minikube-indri, which is slated for retirement; on k3s only ~22 of 70 checks produce results (no static pods). Re-pointing a lean posture check at ringtail is tracked separately ("prowler scan against ringtail").

## What it checks

### Kubernetes CIS benchmarks (Sunday 3am)

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
