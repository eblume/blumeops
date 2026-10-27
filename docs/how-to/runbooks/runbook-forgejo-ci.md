---
title: "Runbook: Forgejo CI"
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Forgejo CI

**Alert names:** `ForgejoRunnerOffline`, `ForgejoCICollectorDown`,
`ForgejoCIQueueStuck`

All three come from the `forgejo_ci_*` metrics. The collector
`darwin/indri/mcquack-forgejo-metrics.sh` (LaunchAgent
`mcquack.eblume.forgejo-metrics`, every 60 s) reads them from Forgejo's sqlite
DB, read-only, and writes them into `forgejo.prom`. The **Forgejo** Grafana
dashboard's CI rows are built on the same metrics.

## ForgejoRunnerOffline

A configured runner hasn't polled Forgejo for 10 minutes. Jobs for its
label queue until it comes back. "Configured" means it has a
`forgejo_ci_runner_capacity` line, generated from `forge/runners.json` by
darwin/indri/configuration.nix.

| Runner | Host | Service |
|--------|------|---------|
| `indri-runner` | [[indri]] | LaunchAgent `mcquack.eblume.forgejo-runner` (user `erichblume`) |
| `indri-build` | [[indri]] | LaunchAgent `mcquack.eblume.forgejo-runner-build` (user `indri-build`, waits for colima) |
| `ringtail-nix-builder-blumeops` | [[ringtail]] | `gitea-runner-nix_container_builder_blumeops.service` |
| `ringtail-nix-builder-horkos` | [[ringtail]] | `gitea-runner-nix_container_builder_horkos.service` |
| `ringtail-nix-builder-hephaestus` | [[ringtail]] | `gitea-runner-nix_container_builder_hephaestus.service` |
| `ringtail-nix-builder-talos` | [[ringtail]] | `gitea-runner-nix_container_builder_talos.service` |
| `ringtail-priv-runner` | [[ringtail]] | `gitea-runner-priv.service` |

The Runner and Service columns mirror `forge/runners.json` (name and unit).

1. **Check the host is up.** For ringtail runners, `ssh ringtail systemctl status
   gitea-runner-<instance>`. For indri runners, `ssh indri launchctl list | grep
   forgejo-runner`.
2. **Read the runner's log:**
   - ringtail: `ssh ringtail journalctl -u gitea-runner-<instance> -n 50`
   - indri: the dashboard's *Forgejo runner logs* panel, or `~/Library/Logs` on indri.
3. **`indri-build` specifically:** its daemon waits for the colima socket
   (`~indri-build/.colima/indri-build/docker.sock`). After an indri reboot, colima
   can take minutes to come up.
   Its host-mode jobs run a GNU userland first on PATH (`timeout`, `sed`,
   `grep`, `find`, `awk`, `tar`, `diff`, `install` from the nix-built
   `indri-build-gnu-userland`), so a script that passes in the pod passes here.
   A job that fails on a BSD-only flag means the step's PATH lost that entry.
4. **A runner was deliberately renamed or retired:** update the runner's
   `capacity` in `forge/runners.json`, so the alert watches the runners
   that actually exist.

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

## ForgejoCIQueueStuck

A job has waited over 30 minutes for a runner on a label where nothing is
running. A label with a job running is served and merely busy, and that case
is deliberately excluded: the one-slot `nix-container-builder` queues jobs
behind a long build for hours, and that is capacity, not a stall. A label with
a queue and nothing running has no runner picking it up.

The alert is per label; `{{ $labels.label }}` names it. Runs blocked on
"Approve and run" never count: Forgejo holds them in status *blocked*, not
*waiting*, and the metric reads only *waiting*.

1. **Is any runner advertising the label?**
   ```fish
   mise run agent-metrics 'forgejo_ci_runner_info'
   ```
   The `labels` label on each series is what the runner registered. If the
   stuck label is on no runner, the runner config was changed in the repo but
   never applied to the live runner. That is what happened on 2026-10-10: the
   `indri-priv` label was merged into the runner role and into the workflow in
   one PR, and the role had not been applied, so a warranted provision-indri
   run (7132) waited 30 minutes with no signal. Apply the runner config, and
   the job starts on its own.
2. **Is the runner that serves it online?** `ForgejoRunnerOffline` fires for
   that case too; follow its steps above.
3. **Is the label served, but only for another repo?** After the per-repo
   registration scoping (#1358, #1520), a runner registered to one repo does
   not take another repo's jobs even when the label matches. Compare the
   runner's scope in the forge UI (Settings, Actions, Runners) with the repo
   whose job is waiting.
4. **Nothing wrong, the label is one nobody serves on purpose** (a workflow
   copied from upstream targeting `ubuntu-latest`, say): cancel the run, and
   fix or remove the workflow so it stops queueing.

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

## Approve and run / trust for the talos bot

PRs opened by the `talos` bot are outside contributions on most repos: their
runs sit behind Forgejo's "Approve and run" banner, and the click is the guard
between PR code and the repo's runners. The `indri-build` runner is reachable
from every PR anyway (unprivileged, lightly sandboxed, shared by all repos),
so on repos with no repo-scoped runner the click protects nothing it does not
already expose — hence the one-time "approve and *always trust*" click per
eligible repo, after which the bot's PRs run CI with no click.

**Do not click** on `blumeops`, `horkos`, `hephaestus` or `talos`: each has a
repo-scoped host-mode runner reachable from a PR's own workflow (blumeops also
both privileged runners). Until those runners move out of PR reach, the per-PR
click stays on those repos.

Mechanics:

- The "always trust" option is offered on a PR's pending-run banner, so the
  click needs a gated PR to exist on the repo. A repo with no
  `pull_request` workflows (today: `agents`, `cv`) shows no banner; the click
  happens on its first gated PR.
- The setting is web-UI only (`action_user` table); there is no API, so
  forge-reconcile can't declare or check it. The eligible list is
  derived from `forge/runners.json` and `argocd/manifests/talos/repos.json`;
  the rule is in `forge/action-trust.nix`, and [[runners-and-trust]] states it.
- Trust expires after 90 days unused: a quiet repo lapses back to one click
  per PR, which fails safe.
