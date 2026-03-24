---
title: Prowler
modified: 2026-03-24
last-reviewed: 2026-03-24
tags:
  - service
  - security
---

# Prowler

CIS Kubernetes Benchmark scanner for compliance posture reporting.

## Quick Reference

| Property | Value |
|----------|-------|
| **Namespace** | `prowler` |
| **Image** | `registry.ops.eblu.me/blumeops/prowler` (see `argocd/manifests/prowler/kustomization.yaml` for current tag) |
| **Schedule** | K8s CIS: Sunday 3am / Image scan: Saturday 3am |
| **Reports** | `sifaka:/volume1/reports/prowler/` and `prowler-images/` (NFS) |
| **Manifests** | `argocd/manifests/prowler/` |

## What it does

Runs Prowler 5 as two CronJobs:

- **K8s CIS scan** (Sunday) — CIS Kubernetes Benchmark v1.11 checks across pod security, RBAC, apiserver, etcd, kubelet, controller-manager, and scheduler
- **Image scan** (Saturday) — CVE, secret, and misconfiguration scanning of all `blumeops/*` container images in the registry via Trivy

Reports are written in HTML, CSV, and JSON-OCSF to the NFS share on sifaka.

## See also

- [[security]] — security & compliance posture overview
- [[deploy-prowler]] — deployment how-to, ad-hoc scan instructions, check relevance notes
- [[read-compliance-reports]] — how to access and interpret reports
