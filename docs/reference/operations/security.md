---
title: Security & Compliance
modified: 2026-03-24
last-reviewed: 2026-03-24
tags:
  - operations
  - security
---

# Security & Compliance

Security posture and compliance scanning for BlumeOps infrastructure.

## Compliance frameworks

| Framework | Tool | Cluster | Notes |
|-----------|------|---------|-------|
| CIS Kubernetes Benchmark v1.11 | [[prowler]] | minikube-indri | Weekly CronJob, ~82 checks |
| PCI DSS v4.0 (K8s mapping) | [[prowler]] | minikube-indri | Reuses CIS checks mapped to PCI requirements |
| ISO 27001:2022 (K8s mapping) | [[prowler]] | minikube-indri | Partial — 22 of 92 controls mapped |

## Scanning tools

- [[prowler]] — CIS Kubernetes Benchmark scanner (weekly CronJob)
  - [[deploy-prowler]] — deployment and ad-hoc scan how-to
  - [[read-compliance-reports]] — accessing and interpreting reports

## Identity & access

- [[authentik]] — SSO/OIDC provider for all web services
- RBAC — Kubernetes role-based access control (audited by Prowler RBAC checks)

## Network & TLS

- [[caddy]] — TLS termination for `*.ops.eblu.me` services
- [[flyio-proxy]] — public ingress via Fly.io tunnel
- Tailscale — zero-trust mesh networking across all nodes

## Secrets management

- [[1password]] — root credential store
- [[external-secrets]] — Kubernetes secrets synced from 1Password

## Reports

All compliance scan reports are stored on `sifaka:/volume1/reports/`. See [[read-compliance-reports]] for access and interpretation.

## Known gaps

- No SOC 2 compliance mapping for Kubernetes (Prowler only maps SOC 2 for AWS/Azure/GCP)
- k3s control plane checks produce no results (embedded binary, no static pods) — consider kube-bench
- No container image vulnerability scanning yet (Prowler has an `image` provider)
- No IaC scanning of manifests/Dockerfiles yet (Prowler has an `iac` provider using Trivy)
