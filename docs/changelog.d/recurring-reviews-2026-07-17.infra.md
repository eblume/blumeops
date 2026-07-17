Service review 2026-07-17 (remote-agent): **authentik 2026.2.2 → 2026.2.6**
(most-stale service; latest patch on the current train — the 2026.5.x train
jump is a separate follow-up). Source bump of the nix-built container via the
Build Container CI dispatch with TOFU hash discovery; go vendorHash and the
client-go pin carry over (go.mod/go.sum unchanged upstream). Also added a
manual-dispatch **Ringtail Flake Update** workflow so remote-agent sessions
can land `flake.lock` bumps via CI on a PR branch.
Added a **Service Health** Grafana dashboard (`uid: service-health`, folder
"Service Health"): degraded deployments/statefulsets, containers stuck
waiting, restart counts, and scrape-target status — the read surface for
agent post-deploy health checks (credential design for agent API access
under discussion).
Reworked `mise run runner-logs` to fetch job logs over the Forgejo web log
route (`…/jobs/N/attempt/M/logs`) with the existing API token — no ssh to
indri needed, so it now works from remote-agent sessions and while logs are
still in dbfs. Also taught the Build Container workflow to post nix build
failures (including TOFU hash mismatches) as PR comments.
