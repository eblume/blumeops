---
title: Read Compliance Reports
modified: 2026-04-06
last-reviewed: 2026-04-06
tags:
  - how-to
  - security
  - compliance
---

# Read Compliance Reports

How to access and interpret compliance scan reports from [[prowler]] and other security scanners.

## Quick summary

```fish
mise run review-compliance-reports
```

This fetches the latest Prowler report from sifaka, parses it (respecting muted status), compares against the previous week, and shows only actionable unmuted failures. Use `--show-muted` to also see muted findings, or `--full` for complete detail.

## Accessing reports

Reports are stored on sifaka at `/volume1/reports/`. Each scanner writes to its own subdirectory:

| Scanner | Path | Schedule |
|---------|------|----------|
| [[prowler]] K8s CIS | `sifaka:/volume1/reports/prowler/` | Weekly (Sunday 3am) |
| [[prowler]] Image | `sifaka:/volume1/reports/prowler-images/` | Weekly (Saturday 3am) |
| [[prowler]] IaC | `sifaka:/volume1/reports/prowler-iac/` | Weekly (Saturday 2am) |

Copy reports to your local machine (remember `scp -O` for sifaka):

```fish
scp -O sifaka:/volume1/reports/prowler/prowler-output-In-Cluster-*.html /tmp/
open /tmp/prowler-output-In-Cluster-*.html
```

## Report formats

### HTML

Open in a browser. Self-contained, filterable by severity, status, and service. Best for human review — shows pass/fail per check with remediation guidance.

### CSV

One row per finding. Columns include check ID, status, severity, resource, namespace, description, and remediation. Good for filtering in a spreadsheet or scripting.

### JSON-OCSF

Open Cybersecurity Schema Framework format. Machine-parseable, suitable for SIEM ingestion or programmatic analysis.

### Compliance CSV

In the `compliance/` subdirectory. Findings mapped to specific framework requirement IDs (e.g., CIS 1.11 section numbers). Shows which controls pass or fail.

## Interpreting results

### Status values

- **PASS** — the resource is configured securely per the check
- **FAIL** — remediation is recommended
- **MANUAL** — Prowler cannot determine the result automatically (e.g., kubelet file permissions when not running on the node)
- **MUTED** — the finding was explicitly suppressed via a mutelist

### Severity

Findings are categorized as **critical**, **high**, **medium**, or **low**. Focus on critical and high first.

### Expected failures

Not all failures require action. Common expected failures in our minikube cluster:

- **Core/pod security (high):** System pods (ArgoCD, external-secrets, tailscale-operator) legitimately need elevated privileges. These can be mutelisted.
- **Apiserver (medium):** Audit logging, profiling, and some admission plugins are not configured in minikube defaults. Low risk for a homelab.
- **Kubelet (high):** Anonymous auth or read-only port settings from minikube defaults.

### Acting on findings

1. **Triage** — review new failures, distinguish real issues from expected noise
2. **Remediate** — fix what you can (pod security contexts, RBAC tightening)
3. **Mutelist** — suppress expected/accepted failures by adding a Resource entry under the matching Check in `argocd/manifests/prowler/mutelist/*.yaml` with a free-form `Description` explaining why
4. **Track** — compare reports over time to spot regressions

## Related

- [[security]] — security & compliance posture overview
- [[deploy-prowler]] — Prowler deployment and ad-hoc scans
- [[kingfisher]] — secret detection scanner
