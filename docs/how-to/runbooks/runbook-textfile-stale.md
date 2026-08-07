---
title: "Runbook: Textfile Stale"
modified: 2026-08-06
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Textfile Stale

**Alert name:** `TextfileStale`

A Prometheus textfile collector `.prom` file on indri has not been updated for
over **2 hours**, indicating the metrics exporter script has stopped running.

The threshold is 2h rather than 1h because `borgmatic.prom` is written by an
**hourly** LaunchAgent — at a 1h threshold its own refresh period is the
threshold, so ordinary scheduling jitter tripped the alert into `pending` every
hour. The other five textfiles are rewritten every 20-50 seconds, so they alert
just as fast in practice.

## Affected Textfiles

| File | LaunchAgent | What it monitors |
|------|-------------|------------------|
| `borgmatic.prom` | `mcquack.eblume.borgmatic` | Backup status |
| `zot.prom` | `mcquack.eblume.zot` | Container registry |
| `forgejo.prom` | `mcquack.eblume.forgejo-metrics` | Git forge |
| `jellyfin.prom` | `mcquack.eblume.jellyfin-metrics` | Media server |
| `macos_power.prom` | `mcquack.eblume.macos-power-metrics` | Host power/thermal |

## Diagnostic Steps

1. **Check which file is stale** — the `file` label in the alert tells you. Verify on indri:
   ```fish
   ssh indri 'ls -la /opt/homebrew/var/node_exporter/textfile/'
   ```

2. **Check if the LaunchAgent is running**:
   ```fish
   ssh indri 'launchctl list | grep mcquack'
   ```

3. **Check LaunchAgent logs** (plist defines stdout/stderr paths):
   ```fish
   ssh indri 'cat ~/Library/Logs/mcquack/<agent-name>.log'
   ```

4. **Try running the exporter manually**:
   ```fish
   ssh indri 'cat ~/Library/LaunchAgents/mcquack.<agent>.plist'
   # Find the ProgramArguments, run them manually
   ```

## Common Causes

- **LaunchAgent not loaded** — `launchctl load ~/Library/LaunchAgents/mcquack.<agent>.plist`
- **Script error** — the exporter script crashed; check logs
- **Permissions** — the textfile directory is not writable
- **Indri reboot** — some LaunchAgents may not auto-start

## Related

- [[alloy]] — Collects textfile metrics via `prometheus.exporter.unix`
- [[deploy-infra-alerting]] — Alerting pipeline overview
