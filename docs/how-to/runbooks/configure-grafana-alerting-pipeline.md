---
title: Configure Grafana Alerting Pipeline
modified: 2026-06-15
last-reviewed: 2026-06-15
tags:
  - how-to
  - alerting
  - grafana
---

# Configure Grafana Alerting Pipeline

Enable Grafana Unified Alerting, create an ntfy webhook contact point, configure the notification policy with anti-noise settings, and set up a message template with runbook links.

## What to Do

### 1. Enable Unified Alerting in grafana.ini

Add the `[unified_alerting]` section to the Grafana ConfigMap. Grafana 11+ has unified alerting enabled by default, but we should be explicit and configure the evaluation interval.

### 2. Create Alerting Provisioning Files

Grafana supports provisioning alert resources via YAML files in `/etc/grafana/provisioning/alerting/`. Create:

- **Contact point** — ntfy webhook. The deployed contact point posts to `https://ntfy.ops.eblu.me` (public Caddy endpoint). Since the [[retire-minikube|k3s migration]] both Grafana and ntfy run on ringtail's k3s, so cluster-internal `http://ntfy.ntfy.svc.cluster.local:80` is now a viable simplification that would avoid the Caddy round-trip — not yet adopted.
- **Notification policy** — root policy with `group_wait: 1m`, `group_interval: 12h`, `repeat_interval: 24h`, grouped by `alertname` and `service`
- **Message template** — format that includes alert name, summary, and a clickable runbook URL as an ntfy action button

### 3. Mount Provisioning into Grafana

Add the alerting provisioning ConfigMap to the Grafana deployment, mounted at `/etc/grafana/provisioning/alerting/`.

### 4. Create the `infra-alerts` Topic

ntfy topics are created on first publish — no explicit setup needed. But verify that the topic works by sending a test notification.

### 5. Verify End-to-End

- Grafana UI shows the ntfy contact point under Alerting → Contact Points
- Notification policy shows the anti-noise settings
- Test notification from Grafana reaches the ntfy iOS app

## Key Details

- Grafana and ntfy both run on ringtail's k3s cluster (since [[retire-minikube]]). The deployed contact point uses the public Caddy URL `https://ntfy.ops.eblu.me`; cluster-internal DNS (`http://ntfy.ntfy.svc.cluster.local`) is now an option but is not currently used.
- ntfy action buttons use the `X-Actions` header or JSON body format: `view, Open Runbook, <url>`
- Grafana provisioning files are applied on startup and cannot be edited from the UI (which is what we want for GitOps)

## Verification

- [ ] Grafana starts with unified alerting enabled
- [ ] Contact point `ntfy-infra` visible in Grafana UI
- [ ] Notification policy shows correct group/repeat intervals
- [ ] Test notification arrives on iOS via ntfy app
- [ ] Test notification includes a clickable runbook link

## Related

- [[deploy-infra-alerting]] — Parent goal
- [[first-alert-and-runbook]] — Next: create the first real alert
