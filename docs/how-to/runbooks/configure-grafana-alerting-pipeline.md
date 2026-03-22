---
title: Configure Grafana Alerting Pipeline
modified: 2026-03-22
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

- **Contact point** — ntfy webhook targeting `http://ntfy.ntfy.svc.cluster.local:80/infra-alerts` (cluster-internal, since Grafana and ntfy are on different clusters, use `ntfy.ops.eblu.me` via Caddy instead)
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

- Grafana runs on minikube (indri), ntfy runs on k3s (ringtail). The contact point URL must go through Caddy: `https://ntfy.ops.eblu.me/infra-alerts`
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
