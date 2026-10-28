---
title: "Runbook: Textfile Stale"
modified: 2026-10-28
last-reviewed: 2026-10-28
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Textfile Stale

**Alert name:** `TextfileStale`

A Prometheus textfile collector `.prom` file on indri has not been updated for
longer than **2× its expected refresh interval** (plus the rule's 15-minute
`for` window), indicating the metrics exporter script has stopped running.

## How the threshold is derived

Each writer declares its own refresh interval in a
`textfile_expected_interval_seconds{file="<basename>.prom"}` gauge, written into
its own `.prom`. The rule (`argocd/manifests/grafana-ringtail/alerting.yaml`)
divides the file's age by that declared interval and fires above 1:

- **Declared** — threshold is 2 × the writer's `textfile_expected_interval_seconds`.
  `forgejo-action-trust.prom` declares 86400 s (fires after 48 h); `borgmatic.prom`
  declares 3600 s (fires after 2 h).
- **Undeclared** — the fallback is 2 h (7200 s). Writers that refresh well inside 2 h
  need no gauge; this covers all of them.

The gauge is the only place the interval lives. To change a writer's cadence,
change the writer and its declared gauge together.

The `file` label is the basename on both sides of the join, so the Alloy export
path (`/opt/homebrew/var/node_exporter/textfile/…`) and the writer's own name
match.

## Affected Textfiles

| File | Writer agent | Cadence | Threshold | What it monitors |
|------|-------------|---------|-----------|------------------|
| `borgmatic.prom` | `mcquack.eblume.borgmatic-metrics` | hourly (declares 3600 s) | 2 h | Backup status |
| `forgejo-action-trust.prom` | `mcquack.eblume.forgejo-action-trust` | daily 05:45 (declares 86400 s) | 48 h | Forgejo action trust declarations |
| `forgejo-mirror-guard.prom` | `mcquack.eblume.forgejo-mirror-guard` | every 10 min | 2 h (fallback) | Mirror ref-guard status |
| `sifaka.prom` | `mcquack.eblume.sifaka-mounter` | every 60 s | 2 h (fallback) | Sifaka SMB share mount |
| `zot.prom` | `mcquack.eblume.zot-metrics` | 60 s | 2 h (fallback) | Container registry |
| `forgejo.prom` | `mcquack.eblume.forgejo-metrics` | 60 s | 2 h (fallback) | Git forge |
| `jellyfin.prom` | `mcquack.eblume.jellyfin-metrics` | 60 s | 2 h (fallback) | Media server |
| `macos_power.prom` | `mcquack.eblume.macos-power-metrics` (root **LaunchDaemon**) | 30 s | 2 h (fallback) | Host power/thermal |

Cadences and thresholds are from the writer plists in
`darwin/indri/configuration.nix`. The list matches the `node_textfile_mtime_seconds`
series Prometheus scrapes for indri.

Most writers are user LaunchAgents (`~/Library/LaunchAgents/`). The
power-metrics writer is a system LaunchDaemon (`/Library/LaunchDaemons/`,
`become: true`), so it needs `sudo` for every step below that touches it.
Don't confuse a writer agent with the service it measures —
`mcquack.eblume.borgmatic` runs the backups and `mcquack.eblume.zot` runs the
registry; the `-metrics` agents are what write the `.prom` files.

**If the alert names a file that is not in this table**, the service it measured
is probably gone and its `.prom` was left behind — Alloy's
`prometheus.exporter.unix` component exports `node_textfile_mtime_seconds` for
every file it finds, so a collector's series outlives the thing it measured.
Don't `rm` it: add the stem to the retired-collector tombstone in
`darwin/indri/configuration.nix`'s postActivation (the `minikube` block's
plist glob + `.prom` removal) and rebuild, which removes the
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
