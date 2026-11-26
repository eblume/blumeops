---
title: "Runbook: indri Memory Thrash"
modified: 2026-11-26
last-reviewed: 2026-11-26
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: indri Memory Thrash

**Alert names:** `ForgejoPageLoadSlow`, `ForgejoProbeFailing`, `IndriSwapHigh`

[[indri]] has 16 GB of RAM. When its processes commit well past that, macOS
pages constantly and every service on the host slows down — most visibly
[[forgejo]], whose PR pages go from about 0.7 s to several seconds, with large
swings between identical requests.

## The alerts

| Alert | Fires when | Signal |
|-------|-----------|--------|
| `ForgejoPageLoadSlow` | 15-minute median of the page probe is above 1.5 s for 15 min | `forgejo_probe_duration_seconds{page="pull"}` — the forgejo metrics collector fetches one fixed PR page from `localhost:3001` every 60 s |
| `ForgejoProbeFailing` | the probe PR page has failed (non-2xx, refused, or timed out) on every check for 10 min | `forgejo_probe_success{page="pull"}` — a failed probe also records 30 s in the duration series, which moves the `ForgejoPageLoadSlow` median only when most checks in its window fail |
| `IndriSwapHigh` | swap in use has stayed above 6 GB for an hour, for 15 min | `node_memory_swap_used_bytes{instance="indri"}` |

`ForgejoPageLoadSlow` is the symptom; `IndriSwapHigh` is the usual cause.
Both firing together is this runbook. `ForgejoPageLoadSlow` alone points at
Forgejo itself (database, git, API polling load) rather than the host.

Two signals that look right and are not used:

- **macOS memory-pressure level** (`kern.memorystatus_vm_pressure_level`)
  reads "normal" while the host thrashes.
- **Swap-in rate** is busy on an ordinary day, so it does not separate a bad
  day from a good one. It is on the **macOS** dashboard for reading next to
  swap usage.

## Diagnose

1. **Who holds the memory.** The **macOS** dashboard's *Largest Processes*
   panel (`macos_process_footprint_bytes`, the 15 largest by footprint) shows
   it over time. Live:

   ```fish
   ssh indri 'top -l 1 -n 15 -o mem -stats pid,command,mem,cmprs'
   ssh indri 'sysctl vm.swapusage'
   ```

   Footprint counts compressed and swapped pages, so a process can show
   gigabytes here with a small resident size.

2. **Is it actively paging.** `ssh indri 'vm_stat 5'` — watch the `swapins`
   and `swapouts` columns (pages per 5 s; a page is 16 KiB).

3. **How slow, and since when.** The **Forgejo** dashboard's *Page load*
   panel. For real page views by handler, the router log is in Loki under
   `{host="indri", service="forgejo"}`; each `router: completed` line carries
   the server time.

## Known holders

| Process | Notes |
|---------|-------|
| `fseventsd` | The macOS file-event daemon. Its footprint has been seen growing to 15 GB+ over weeks of uptime. Remediation: see [Remediation: fseventsd](#remediation-fseventsd). |
| `com.apple.Virtua…` | The colima build VM (`darwin/indri/colima-indri-build.yaml`), sized at 6 GB. |
| `forgejo` | Live Go heap is small; the footprint keeps the high-water mark of earlier spikes. |

## Remediation: fseventsd

- **Automatic path.** A root LaunchDaemon, `mcquack.eblume.fseventsd-watchdog`, runs `/usr/local/bin/fseventsd-watchdog` every 5 minutes. When fseventsd's footprint (top's MEM column: resident + compressed + swapped) is above 2 GB (`THRESHOLD_BYTES` at the top of `darwin/indri/mcquack-fseventsd-watchdog.sh`), it runs `killall fseventsd`, and launchd's keep-alive restarts it. At most one restart per hour (`RESTART_HOLDOFF_SECONDS`); a restart that the hourly guard blocks is reported as `held`.
- **Textfile.** `fseventsd-watchdog.prom` (see the `TextfileStale` row of [[runbook-textfile-stale]]) exports:
  - `macos_fseventsd_footprint_bytes`
  - `macos_fseventsd_watchdog_threshold_bytes`
  - `macos_fseventsd_watchdog_restarts_total`
  - `macos_fseventsd_watchdog_last_restart_timestamp_seconds`
  - `macos_fseventsd_watchdog_held`
  - `macos_fseventsd_watchdog_last_restart_ok` (outcome of the watchdog's most recent restart: 1 if it brought up a new fseventsd pid, 0 if the pid was unchanged or fseventsd did not come back; it changes only on watchdog restarts)
  - `macos_fseventsd_up`
- **When to act by hand.** `macos_fseventsd_watchdog_held` stays 1 across several ticks, or `macos_fseventsd_watchdog_last_restart_ok` is 0 after a restart, or the footprint climbs back over threshold faster than hourly restarts can hold.
- **Manual restart.** `ssh indri 'sudo killall fseventsd'`. launchd restarts it by keep-alive. Confirm with `ssh indri 'pgrep -x fseventsd'` (a new pid). `macos_fseventsd_watchdog_last_restart_ok` does not change for a manual kill; it reflects only watchdog-issued restarts. Use `killall`, not `launchctl kickstart -k system/com.apple.fseventsd`, which SIP may refuse.
- **What a restart costs.**
  - Events not yet flushed to the on-disk log are dropped, and clients are told to rescan.
  - Spotlight (mds) does a deeper scan afterwards.
  - Borgmatic backups do not use file events, so they are unaffected.
  - Whether every live subscriber's stream resumes cleanly is not confirmed. Forgejo, zot, Caddy and the runners are not believed to subscribe (Go file watching on macOS uses kqueue), but that has not been checked process by process. If something that watches files goes quiet after a restart, suspect this first.
- **After a restart.** Check that `ForgejoPageLoadSlow` recovers and that `IndriSwapHigh` clears over the following hour (the Forgejo dashboard's *Page load* panel and the macOS dashboard's swap panel).

## Related

- [[runbook-textfile-stale]] — if `process_memory.prom` or `forgejo.prom` stops updating
- [[forgejo]], [[indri]], [[alloy]]
