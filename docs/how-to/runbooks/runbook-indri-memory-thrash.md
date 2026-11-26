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
| `ForgejoProbeFailing` | the probe PR page has failed (non-2xx, refused, or timed out) on every check for 10 min | `forgejo_probe_success{page="pull"}` — a failed probe also records 30 s in the duration series, so `ForgejoPageLoadSlow` sees it too |
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
| `fseventsd` | The macOS file-event daemon. Its footprint has been seen growing to 15 GB+ over weeks of uptime. |
| `com.apple.Virtua…` | The colima build VM (`darwin/indri/colima-indri-build.yaml`), sized at 6 GB. |
| `forgejo` | Live Go heap is small; the footprint keeps the high-water mark of earlier spikes. |

## Related

- [[runbook-textfile-stale]] — if `process_memory.prom` or `forgejo.prom` stops updating
- [[forgejo]], [[indri]], [[alloy]]
