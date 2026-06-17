---
title: First Alert and Runbook
modified: 2026-06-17
last-reviewed: 2026-06-17
tags:
  - how-to
  - alerting
---

# First Alert and Runbook

> **Status (2026-06-17):** This POC is **complete and deployed.** The
> `ServiceProbeFailure` alert rule, the `ntfy-infra` webhook contact point, and
> the runbook template all live in `argocd/manifests/grafana-ringtail/alerting.yaml`.
> The runbook it links to is [[runbook-service-probe-failure]].
>
> **Coverage caveat:** the blackbox probe set has since been reduced to a single
> target (`immich`) in `argocd/manifests/alloy-ringtail/config.alloy`. The
> original five-service list below (miniflux, kiwix, transmission, devpi,
> argocd) is historical — `devpi` has been retired and the others lost their
> probes during the observability refactor, so only an `immich` outage fires
> this alert today. See [[port-services-check-alerts]] for re-expanding
> coverage. This card is retained as the design rationale for the deployed
> alert.

Create one end-to-end alert as proof of concept — an alert rule that fires, delivers a notification to ntfy with a runbook link, and has a corresponding runbook doc.

## What to Do

### 1. Choose the First Alert

The best candidate is a **blackbox probe failure** because:
- Alloy's blackbox exporter probes in-cluster services at 30s intervals (currently only `immich`; historically miniflux, kiwix, transmission, devpi, argocd)
- The metric `probe_success` is already in Prometheus
- It maps directly to what services-check does (HTTP health checks)
- A single alert rule with a `service` label can cover all probed services

### 2. Create the Alert Rule

Provision via YAML in the alerting provisioning ConfigMap. The rule should:
- Query `probe_success == 0` from Prometheus
- Fire after the condition persists for 2 minutes (avoid flapping)
- Include labels: `severity: warning`, `service: {{ $labels.instance }}`
- Include annotations: `summary`, `runbook_url` pointing to the runbook doc

### 3. Create the Runbook

Write `docs/how-to/runbooks/runbook-service-probe-failure.md` as a how-to doc explaining:
- What the alert means
- How to check which service is down
- Common causes and resolution steps
- How to silence the alert if the downtime is planned

### 4. Verify End-to-End

- Stop one of the probed services (e.g., scale miniflux to 0)
- Wait for the alert to fire (~2 minutes)
- Confirm ntfy notification arrives with correct summary and runbook link
- Click the runbook link and verify it reaches docs.eblu.me
- Scale the service back up
- Confirm "resolved" notification arrives
- Confirm no repeat notification during the 24h window

## Key Details

- Grafana alert rules can be provisioned as YAML files alongside contact points and notification policies
- The blackbox probe metrics from Alloy use the job name `blackbox` and include an `instance` label with the service name
- The runbook URL format: `https://docs.eblu.me/how-to/runbooks/runbook-service-probe-failure`

## Verification

- [ ] Alert rule appears in Grafana UI under Alerting → Alert Rules
- [ ] Simulated failure triggers ntfy notification within ~3 minutes
- [ ] Notification includes service name, summary, and clickable runbook link
- [ ] Resolution triggers a "resolved" notification
- [ ] No repeat notification within 24h window

## Related

- [[configure-grafana-alerting-pipeline]] — Prerequisite: pipeline must be working
- [[deploy-infra-alerting]] — Parent goal
- [[port-services-check-alerts]] — Next: port remaining checks
- [[runbook-service-probe-failure]] — The runbook created for this alert
