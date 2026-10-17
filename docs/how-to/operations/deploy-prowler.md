---
title: Deploy Prowler CIS Scanner
modified: 2026-10-17
last-reviewed: 2026-10-17
tags:
  - how-to
  - kubernetes
  - security
  - compliance
---

# Deploy Prowler CIS Scanner

Prowler runs a weekly CIS Kubernetes Benchmark scan against the ringtail k3s cluster (the `prowler-ringtail` app — prowler scans the cluster it runs in) and writes HTML/CSV/JSON-OCSF reports to the NFS share on sifaka. Only the K8s CIS scan runs — image-CVE and IaC scanning are out of scope; if image-CVE signal is wanted, the shape is critical-severity-only, currently-deployed-tags-only, alert-on-new (tracked as the "Trivy for image/IaC scanning" task).

## What it checks

### Kubernetes CIS benchmarks (Sunday 3am)

Prowler's Kubernetes provider ships 93 checks in v5.39.1; the scan runs with `--compliance cis_1.11_kubernetes`, which limits it to the 82 checks mapped into the CIS Kubernetes Benchmark v1.11, grouped into:

| Category | Checks | How it works |
|----------|--------|-------------|
| **Core (pod security)** | 13 | Queries K8s API for privileged containers, hostPID/hostNetwork, capabilities, secrets in env vars, seccomp |
| **RBAC** | 9 | Queries RBAC API for overprivileged roles, wildcard access, cluster-admin bindings |
| **Apiserver** | 28 | Inspects `kube-apiserver` pod args in kube-system (TLS, auth, audit, admission plugins) |
| **Etcd** | 7 | Inspects `etcd` pod args (TLS, cert auth) |
| **Controller Manager** | 7 | Inspects `kube-controller-manager` pod args |
| **Kubelet** | 16 | Reads kubelet-config ConfigMap + node file permissions (file checks need hostPID) |
| **Scheduler** | 2 | Inspects `kube-scheduler` pod args |

**k3s reality:** k3s embeds the control plane in a single binary — no static control-plane pods exist — so only the core, RBAC and kubelet categories produce results. The node-level conditions the in-cluster scanner cannot fully evaluate (file permissions, kubelet config, etcd CA separation, cluster-admin bindings) are verified separately by `review-compliance-reports` over `ssh ringtail`.

The mutelist carries only entries that match live k3s resources. Its six MANUAL rows — the kubelet node-file ownership/permissions checks (kubelet.conf, config.yaml, service drop-in) — are files the scanner cannot read from a pod; the node verifier covers them, so they are muted. The steady-state report also carries 20 unmuted FAILs week over week — 19 RBAC rows (newer checks such as `rbac_minimize_secret_access`, plus built-in resources like `Group:system:masters` that the mutelist predates) and one seccomp row for the egress-gateway pod. Accepted as-is: the scan runs as a tripwire for new deltas, no action is taken on those rows. Consider `kube-bench` for a deeper k3s control-plane check.

## Reports

Reports are written to `sifaka:/volume1/reports/prowler/` with timestamped filenames. See [[read-compliance-reports]] for how to access and interpret them.

## Running an ad-hoc scan

```fish
kubectl create job --from=cronjob/prowler prowler-manual -n prowler --context=k3s-ringtail
```

Watch progress:

```fish
kubectl logs -f job/prowler-manual -n prowler --context=k3s-ringtail
```

## Container

Nix build at `containers/prowler/default.nix` — wraps nixpkgs' `prowler`
(5.39.1) plus `python3`/`pyyaml` for the mutelist-merge initContainer. The
build host's nixos-26.05 `nixpkgs` pins prowler 5.12.3, so the file
self-pins a `nixos-unstable` rev carrying 5.39.1 instead; a version
assertion fails the build if a nixpkgs move changes the bundled prowler,
and service-review re-bumps the pin. See [[build-container-image]] for the
build/release process.

Source is mirrored at `forge.ops.eblu.me/mirrors/prowler`.

## See also

- [[security]] — security & compliance posture overview
- [[read-compliance-reports]] — how to access and interpret scan reports
- [[deploy-k8s-service]] — general K8s deployment how-to
- [[build-container-image]] — container build pipeline
