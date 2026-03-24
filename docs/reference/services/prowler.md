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
| **Schedule** | Weekly (Sunday 3am) |
| **Reports** | `sifaka:/volume1/reports/prowler/` (NFS) |
| **Manifests** | `argocd/manifests/prowler/` |

## What it does

Runs Prowler 5 as a CronJob against minikube-indri, executing CIS Kubernetes Benchmark v1.11 checks across pod security, RBAC, apiserver, etcd, kubelet, controller-manager, and scheduler. Reports are written in HTML, CSV, and JSON-OCSF to the NFS share on sifaka.

## See also

- [[security]] — security & compliance posture overview
- [[deploy-prowler]] — deployment how-to, ad-hoc scan instructions, check relevance notes
- [[read-compliance-reports]] — how to access and interpret reports
