Talos v0.3.1: SSE stream reliability — server heartbeat + client resync
close the "new messages don't appear until re-entry" gap (talos PR #12),
with the reconnect path hardened in review (tracked EventSource, resync
on manual reconnect, backoff, stale-resync guard).
