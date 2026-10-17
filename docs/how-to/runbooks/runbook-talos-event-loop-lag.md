---
title: "Runbook: Talos Event Loop Lag"
modified: 2026-10-16
last-reviewed: 2026-10-16
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Talos Event Loop Lag

**Alert name:** `TalosEventLoopLag`

The talos pod's Bun main thread has been blocked for more than 20% of wall
time over the trailing 15 minutes, sustained for 5 minutes, and the pod has
been up for more than 15 minutes. The condition is
`rate(talos_event_loop_lag_seconds_sum[15m]) > 0.2`: the `_sum` rate is the
fraction of wall time the event loop spends blocked, so the alert fires only
on sustained blocking, never on a single 5 s stall. The boot grace suppresses
it for the first 15 minutes after a pod start, when the session-index rebuild
and boot replay storm can legitimately block the loop. A recurring 5–10 s
stall about once an hour stays far below the threshold and below the 15 s
probe timeout, so it does not page.

Sustained stalls starve `/healthz` — served by the same event loop on the
metrics port (:9464) — past its 15 s probe timeout, so the readiness probe
(period 10 s, timeout 15 s) starts failing and, once a stall blocks long enough
for `failureThreshold` to accumulate, the liveness probe trips and the pod is
restarted, taking every session down with it.

## Diagnostic Steps

1. **Correlate with the pod log.** The stall is logged at the moment it
   happens. Read the talos pod log from ringtail and match the timestamps
   against the alert's firing time:

   ```fish
   kubectl -n talos logs --timestamps deploy/talos | grep -E 'event loop stalled|session-index sync slow|issues queue rebuilt|liveSessionInfos slow'
   ```

   `event loop stalled N s` is the stall itself; the other patterns are the
   known long-running work that can accompany it.

2. **Check the dashboard.** Grafana → the **Talos** dashboard: the "Event loop
   lag (p50/p99)" panel shows the stall shape, and the "Event loop: blocked
   wall time" panel shows what fraction of wall time the loop spent blocked
   over the trailing 5 minutes.

3. **A pod that just restarted or cold-booted is doing a session-index rebuild
   or boot replay storm.** That can still legitimately stall briefly even after
   the sliced index build of [eblume/talos#352](https://forge.ops.eblu.me/eblume/talos/issues/352)
   — give boot time to settle before treating a stall as a problem.

4. **Otherwise attribute to in-process turns or GC.** A heavy in-process turn
   or a long GC pause can block the main thread. If the stall is not
   boot-related, escalate to the
   [eblume/talos#345](https://forge.ops.eblu.me/eblume/talos/issues/345) thread
   with the log excerpt and timestamps.

## Known Good

The sliced index build of
[eblume/talos#352](https://forge.ops.eblu.me/eblume/talos/issues/352) made the
session-index build yield, so boot-time stalls from the rebuild are bounded and
largely gone. A cold boot can still stall briefly (a boot replay storm replays
many sessions' events), but a sustained stall that outlives boot is not
expected and should be attributed and escalated per step 4.

## Related

- [[observability]] — the observability stack the alert runs on
- [[runbook-pod-not-ready]] — readiness/liveness failures and their causes
