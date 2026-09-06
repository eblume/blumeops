---
title: Read Compliance Reports
modified: 2026-09-05
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

> **Retired (2026-06):** the Prowler **image** (`prowler-images/`) and **IaC**
> (`prowler-iac/`) scans were retired. They produced tens of thousands of
> un-actioned, un-muted findings every week — mostly unpatchable upstream-image
> CVEs and systemic pod-security KSV warnings — and nobody triaged them. See
> [[deploy-prowler#Why only the K8s CIS scan]] for the rationale. Their stale
> report directories may linger on sifaka until manually removed.

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

Not all failures require action. Common expected failures in our k3s cluster on ringtail:

- **Core/pod security (high):** k3s system pods (coredns, local-path-provisioner), Tailscale operator-managed pods (ts-*, ingress-*), and node agents (alloy-tracing, nvidia-device-plugin) legitimately need elevated privileges — the Prowler scanner itself runs with hostPID to read node files. These are mutelisted per-resource under `argocd/manifests/prowler-ringtail/mutelist/`.
- **RBAC (high/medium):** built-in Kubernetes roles (cluster-admin, system:*), k3s built-in components, and the SSO-gated ArgoCD role require broad permissions by design.

### Acting on findings

1. **Triage** — review new failures, distinguish real issues from expected noise
2. **Remediate** — fix what you can (pod security contexts, RBAC tightening)
3. **Mutelist** — suppress expected/accepted failures by adding a Resource entry under the matching Check in `argocd/manifests/prowler-ringtail/mutelist/*.yaml` with a free-form `Description` explaining why
4. **Track** — compare reports over time to spot regressions

## Node verification

The weekly review also verifies k3s node-level conditions that the scan cannot fully evaluate: k3s/kubelet file ownership and permissions (k3s.yaml, admin.kubeconfig, kubelet.kubeconfig, k3s.service), the kubelet config drop-ins under `/var/lib/rancher/k3s/agent/etc/`, etcd CA separation (etcd-ca.crt vs ca.crt), and RBAC cluster-admin bindings. It runs over `ssh ringtail` (needs passwordless sudo) and `kubectl --context=k3s-ringtail` (set up with `mise run ensure-k3s-ringtail-kubectl-config`), and fails loudly on any drift.

The k3s Prowler profile currently emits no MANUAL findings, so this is a drift safety net over node configuration rather than a check of reported findings.

## Related

- [[security]] — security posture overview
- [[deploy-prowler]] — Prowler deployment and ad-hoc scans
