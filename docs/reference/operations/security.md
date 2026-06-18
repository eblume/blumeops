---
title: Security
modified: 2026-06-17
last-reviewed: 2026-06-17
tags:
  - operations
  - security
---

# Security

Security posture and periodic scanning for BlumeOps infrastructure.

> BlumeOps runs a weekly CIS Kubernetes Benchmark scan as a hygiene check, not as part of a formal compliance program. It once doubled as a PCI DSS / SOC 2 practice environment; that framing has been retired. The scan stays because it's a cheap, useful baseline — findings are triaged, remediated, or mutelisted with a written justification.

## Scanning tools

- [[prowler]] — CIS Kubernetes Benchmark scanner (weekly CronJob on ringtail). The container-image CVE scan and IaC scan were retired in 2026-06 (un-actioned noise — see [[deploy-prowler#Why only the K8s CIS scan]]); only the K8s CIS scan remains.
  - [[deploy-prowler]] — deployment and ad-hoc scan how-to
  - [[read-compliance-reports]] — accessing and interpreting reports
- Secret detection — [TruffleHog](https://github.com/trufflesecurity/trufflehog) runs as a prek hook on every commit/push.

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

All scan reports are stored on `sifaka:/volume1/reports/`. See [[read-compliance-reports]] for access and interpretation.

Suppressed findings are kept in Prowler mutelist YAML under `argocd/manifests/prowler-ringtail/mutelist/`. Each entry's `Description` field explains why the finding is muted; entries are reviewed ad-hoc rather than on a scheduled cadence.

## Known gaps

- k3s control plane checks produce no results (embedded binary, no static pods) — consider kube-bench
- No container-image CVE scanning (the Prowler image scan was retired 2026-06 as un-actioned noise). If reintroduced, scope it to critical-severity, currently-deployed tags, alert-on-new
- No automated IaC misconfiguration scanning (the Prowler IaC scan was retired 2026-06). Manifest pod-security hardening is now an accept-and-document decision rather than a weekly report
