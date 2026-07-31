EVE Online game state now publishes itself into heph. An hourly systemd **user**
timer on ringtail (`nixos/ringtail/myeve-heph-sync.nix`) runs the MyEVE sync,
filing PI extractor expiry, undelivered industry jobs, skill-queue exhaustion and
undercut market orders as tasks under the MyEVE project — and closing them again
when the game state resolves. The motivating case: a manufacturing job finished
2026-07-18 and sat undelivered for 12 days because nothing surfaced it.

User scope is load-bearing, the same constraint as the eblume heph spoke — the
sync shells out to `heph`, which needs `XDG_RUNTIME_DIR` to find `hephd.sock`. A
system service would bind the `~/.local/share` fallback and never meet the spoke.
The unit skips cleanly when the CLI, the myeve checkout, the ESI token or the
socket is missing, and fails loudly only when the ESI refresh token is revoked.

The sync logic lives in the myeve repo and gained matching fixes: reconciliation
is now keyed purely on the `myeve-key:` line in each task's context doc, with the
heph store as the only state. The local cache file it used to depend on could be
lost, and when it was, every live chore looked new — duplicates filed, originals
stranded beyond the reach of the closer. Two further bugs fell out: a collector
that raised had its live chores closed as if resolved (one flaky ESI call could
close "deliver your finished job"), and `--only pi` closed every non-PI chore.
Both now scope closing to the collectors that actually ran.
