---
title: "Runbook: Forgejo CI"
modified: 2026-10-10
last-reviewed: 2026-10-10
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Forgejo CI

**Alert names:** `ForgejoRunnerOffline`, `ForgejoCICollectorDown`

Both come from the `forgejo_ci_*` metrics. The collector
`darwin/indri/mcquack-forgejo-metrics.sh` (LaunchAgent
`mcquack.eblume.forgejo-metrics`, every 60 s) reads them from Forgejo's sqlite
DB, read-only, and writes them into `forgejo.prom`. The **Forgejo** Grafana
dashboard's CI rows are built on the same metrics.

## ForgejoRunnerOffline

A configured runner hasn't polled Forgejo for 10 minutes. Jobs for its
label queue until it comes back. "Configured" means it has a
`forgejo_ci_runner_capacity` line in the collector script.

| Runner | Host | Service |
|--------|------|---------|
| `indri-runner` | [[indri]] | LaunchAgent `mcquack.eblume.forgejo-runner` (user `erichblume`) |
| `indri-build` | [[indri]] | runner daemon as user `indri-build` (waits for colima) |
| `ringtail-nix-builder` | [[ringtail]] | `gitea-runner-nix_container_builder.service` |
| `ringtail-priv-runner` | [[ringtail]] | `gitea-runner-priv.service` |

1. **Check the host is up.** For ringtail runners, `ssh ringtail systemctl status
   gitea-runner-<instance>`. For indri runners, `ssh indri launchctl list | grep
   forgejo-runner`.
2. **Read the runner's log:**
   - ringtail: `ssh ringtail journalctl -u gitea-runner-<instance> -n 50`
   - indri: the dashboard's *Forgejo runner logs* panel, or `~/Library/Logs` on indri.
3. **`indri-build` specifically:** its daemon waits for the colima socket
   (`~indri-build/.colima/indri-build/docker.sock`). After an indri reboot, colima
   can take minutes to come up.
4. **A runner was deliberately renamed or retired:** update the
   `forgejo_ci_runner_capacity` lines in the collector script, so the alert
   watches the runners that actually exist.

## ForgejoCICollectorDown

`forgejo_ci_collector_up` is 0: the `sqlite3` read of
`~/forgejo/data/forgejo.db` failed. Every `forgejo_ci_*` series is missing,
along with `forgejo_repo_latest_commit_timestamp_seconds` and
`forgejo_actions_last_success_timestamp_seconds`, which come from the same
query. The API-sourced repo metrics keep the file fresh, so `TextfileStale`
stays quiet.

1. Reproduce the error. The collector hides sqlite's stderr, so copy the
   `ci_sql` heredoc out of `darwin/indri/mcquack-forgejo-metrics.sh` into a
   file on indri and run it by hand:
   ```fish
   ssh indri 'sqlite3 -readonly ~/forgejo/data/forgejo.db < /tmp/ci.sql | head'
   ```
2. **After a Forgejo upgrade**, a schema change is the likely cause: a renamed
   `action_*` column or a changed status enum. Fix the query to match.
3. **"database is locked"** past the 5 s busy timeout means a long write, such as
   a migration. It should clear on its own.

## Reading the CI dashboard

- **Queue wait** is measured from when a job became ready (created, or its
  `needs` finished) to when a runner picked it up. `gate="approval"` runs are
  agent fork PRs, so their wait includes your "Approve and run" click. Those are
  kept off the capacity panels.
- **Utilization** is occupied slots divided by `forgejo_ci_runner_capacity`.
  If a label has high utilization and a rising queue-wait p90 at steady volume,
  it needs more slots.
- **"PRs awaiting approval"** counts only open PRs. Runs on closed PRs stay
  blocked in the DB forever and are ignored.
