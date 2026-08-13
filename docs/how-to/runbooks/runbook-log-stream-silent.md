---
title: "Runbook: Log Stream Silent"
modified: 2026-08-13
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Log Stream Silent

**Alert names:** `LogStreamSilentForgejo`, `LogStreamSilentForgejoRunner`,
`LogStreamSilentZot`, `LogStreamSilentTailscaled`

One of indri's always-active log streams has stopped arriving in Loki. These
alerts fire on **NoData** — a Loki stream with no lines in the window returns
no series at all — so a firing instance means "zero lines", not "few lines".
The window is per-stream, sized to that stream's guaranteed traffic.

## First: one alert, or all four?

**All four firing together is the "alloy is down" signature** — the tail
process itself, not any individual file. Check the daemon:

```fish
ssh indri 'launchctl list mcquack.eblume.alloy; tail -20 ~/Library/Logs/mcquack.alloy.err.log'
```

A config error on restart looks exactly like this: alloy exits on a bad
`config.alloy`, launchd relaunches it, and the loop ships nothing. The
generated config lives at the path in `ansible/roles/alloy/defaults/main.yml`
(`alloy_config_dir`); re-render with `mise run provision-indri -- --tags alloy
--check --diff` before touching it by hand.

## Watched streams

| Alert | File | Window | Guaranteed by |
|-------|------|--------|---------------|
| LogStreamSilentForgejo | `mcquack.forgejo.out.log` | 24h | forge logs every request |
| LogStreamSilentForgejoRunner | `mcquack.forgejo-runner.err.log` | 48h | runner logs each CI job to stderr; scheduled workflows run daily |
| LogStreamSilentZot | `mcquack.zot.out.log` | 24h | pull-through cache + CI traffic |
| LogStreamSilentTailscaled | `/opt/homebrew/var/log/tailscaled.log` | 24h | tailscaled logs constantly |

The other declared files (`forgejo.err`, `forgejo-runner.out`, `zot.err`,
`jellyfin.err`, `alloy.out`, `borgmatic.out`) are quiet by nature — each
service writes to one fd — and are deliberately unwatched. So is
`jellyfin.out` (~50 lines/day, too sparse to alert on). borgmatic freshness
has its own alert (`BorgmaticStale`).

## Single alert: is it the source or the shipping?

1. **Is the file growing on the host?**

   ```fish
   ssh indri 'ls -la ~/Library/Logs/mcquack.*.log /opt/homebrew/var/log/tailscaled.log'
   ```

   A file that stopped growing is a *service* problem (or a LaunchAgent
   redirect problem after a plist change), not a shipping problem — go look at
   that service.

2. **Is alloy tailing it?** Alloy's own metrics are remote-written to
   Prometheus (`prometheus.scrape "alloy_self"` in the config template), so
   this works from anywhere, agent pods included:

   ```fish
   mise run agent-metrics 'loki_source_file_read_lines_total{instance="indri"}'
   mise run agent-metrics 'rate(loki_write_dropped_entries_total{instance="indri"}[1h])'
   ```

   A path missing from `loki_source_file_read_lines_total` means the tail
   never matched: check the path in `alloy_mcquack_logs` /
   `alloy_brew_logs` against the plist's `StandardOutPath`/`StandardErrorPath`
   (the defaults file states this invariant), and check file permissions.
   Lines read but entries dropped points at the push side: Loki ingest,
   Caddy route, or the tailnet path.

3. **Check what Loki has, from anywhere** (Grafana → Explore → Loki, or the
   datasource proxy):

   ```logql
   sum by (filename) (count_over_time({host="indri"}[24h]))
   ```

## After a fix

Alloy tails from the current end of file — after restarting it, make the
service log something before judging, and expect up to `for: 1h` +
one evaluation interval before the alert resolves.
