---
title: "Runbook: Textfile Stale"
modified: 2026-08-24
last-reviewed: 2026-08-24
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Textfile Stale

**Alert name:** `TextfileStale`

A Prometheus textfile collector `.prom` file on indri has not been updated for
over **2 hours** (plus the rule's 15-minute `for` window), indicating the
metrics exporter script has stopped running.

The threshold is 2h rather than 1h because `borgmatic.prom` is written by an
**hourly** LaunchAgent — at a 1h threshold its own refresh period is the
threshold, so ordinary scheduling jitter tripped the alert into `pending` every
hour. The other four textfiles are rewritten every 30–60 seconds, so they alert
just as fast in practice.

## Affected Textfiles

| File | Writer agent | What it monitors |
|------|-------------|------------------|
| `borgmatic.prom` | `mcquack.eblume.borgmatic-metrics` (hourly) | Backup status |
| `zot.prom` | `mcquack.eblume.zot-metrics` | Container registry |
| `forgejo.prom` | `mcquack.eblume.forgejo-metrics` | Git forge |
| `jellyfin.prom` | `mcquack.eblume.jellyfin-metrics` | Media server |
| `macos_power.prom` | `mcquack.eblume.macos-power-metrics` (root **LaunchDaemon**) | Host power/thermal |

The first four are user LaunchAgents (`~/Library/LaunchAgents/`). The
power-metrics writer is a system LaunchDaemon (`/Library/LaunchDaemons/`,
`become: true`), so it needs `sudo` for every step below that touches it.
Don't confuse a writer agent with the service it measures —
`mcquack.eblume.borgmatic` runs the backups and `mcquack.eblume.zot` runs the
registry; the `-metrics` agents are what write the `.prom` files.

**If the alert names a file that is not in this table**, the service it measured
is probably gone and its `.prom` was left behind — Alloy's
`prometheus.exporter.unix` component exports `node_textfile_mtime_seconds` for
every file it finds, so a collector's series outlives the thing it measured.
Don't `rm` it: add the stem to `alloy_retired_collectors` in
`ansible/roles/alloy/defaults/main.yml` and re-provision, which removes the
file *and* any LaunchAgent still writing it. A hand deletion comes back the
next time either one runs.

## Diagnostic Steps

1. **Check which file is stale** — the `file` label in the alert tells you. Verify on indri:
   ```fish
   ssh indri 'ls -la /opt/homebrew/var/node_exporter/textfile/'
   ```
   (The directory is named after node_exporter for compatibility — the actual
   scraper is [[alloy]].)

2. **Check if the writer agent is running**:
   ```fish
   ssh indri 'launchctl list | grep mcquack'                    # user agents
   ssh indri 'sudo launchctl list | grep mcquack'               # daemons
   ```

3. **Check the writer's logs** (each agent's plist names its own paths):
   ```fish
   ssh indri 'cat /opt/homebrew/var/log/mcquack.<agent>.out.log'
   ssh indri 'cat /opt/homebrew/var/log/mcquack.<agent>.err.log'
   # the power-metrics daemon logs to /var/log/mcquack.macos-power-metrics.*.log
   # (jellyfin is the exception: /opt/homebrew/var/log/jellyfin-metrics.*.log)
   ```

4. **Try running the exporter manually**:
   ```fish
   ssh indri 'cat ~/Library/LaunchAgents/mcquack.<agent>.plist'
   # the daemon's plist is /Library/LaunchDaemons/mcquack.macos-power-metrics.plist
   # Find the ProgramArguments, run them manually (sudo for the daemon)
   ```

## Common Causes

- **Agent not loaded** — `launchctl load ~/Library/LaunchAgents/mcquack.<agent>.plist`
  (or `sudo launchctl load /Library/LaunchDaemons/mcquack.macos-power-metrics.plist` for the daemon)
- **Script error** — the exporter script crashed; check logs
- **Permissions** — the textfile directory is not writable
- **Indri reboot** — some agents may not auto-start

## Related

- [[alloy]] — Collects textfile metrics via `prometheus.exporter.unix`
- [[deploy-infra-alerting]] — Alerting pipeline overview
