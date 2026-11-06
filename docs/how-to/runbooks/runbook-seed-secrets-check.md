---
title: "Runbook: Seed Secrets Check"
modified: 2026-11-06
last-reviewed: 2026-11-06
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Seed Secrets Check

**Alert names:** `SeedSecretsCheckFailed`, `SeedSecretsCheckStale`, `SeedSecretsCheckStaleIndri`

The weekly vault-free drift gate for the on-host secret files declared in
`nixos/ringtail/secrets.json` (ringtail) and `darwin/indri/secrets.json`
(indri). Each week a root job on the host itself runs
the `/etc/blumeops/mise-tasks/seed-secrets` script in a nix-built Python
env (rich + typer, the script's declared deps — the run is fully offline
from the store): `--check --local` verifies every declared file's
presence/owner/group/mode and scans the managed directories for stray files
(see [[seed-secrets]] and
eblume/blumeops#1524). ringtail's job is the systemd timer
`seed-secrets-check.timer`; indri's is the launchd daemon
`mcquack.eblume.seed-secrets-check` (Sunday 05:30 and at load). The gate is
host-local because the CI runner has no ssh+sudo route back to either host;
`--local` also needs no vault and no 1Password.

The check's verdict is written to `/var/lib/seed-secrets/seed-secrets.prom`
(two gauges — `seed_secrets_check_ok` and
`seed_secrets_check_timestamp_seconds`), scraped by ringtail's Alloy textfile
collector (indri: node_exporter textfile dir) and remote-written to the
in-cluster Prometheus with `cluster="ringtail"` or `cluster="indri"`. The
alerts:

- **`SeedSecretsCheckFailed`** — `seed_secrets_check_ok == 0` for 15m on
  either cluster: the last run was red (drifted file, stray file, or an
  `UNKNOWN` — a check that cannot see is a failure). The summary names the
  cluster.
- **`SeedSecretsCheckStale`** (ringtail) and **`SeedSecretsCheckStaleIndri`**
  — last timestamp older than 8 days (7d interval + 1d margin), or no series
  at all. ringtail's timer also fires once at boot (`OnBootSec=15min`); indri's
  daemon runs at load (`RunAtLoad`). Either way a fresh deploy writes the
  series inside the 1h `for` window; a *missing* series is still exactly this
  failure, so the rule alerts on NoData.

The unit itself always exits 0 — a red check must not flap the unit; the
metric and these rules carry the state.

## Diagnostic Steps

1. **Which alert fired?**
   - `SeedSecretsCheckFailed`: the check ran and found drift — read the
     journal for what.
   - `SeedSecretsCheckStale`: the timer never ran (including the boot run
    after a fresh deploy), or its output is stale.

2. **Check the job and the last run** on the host.
   ringtail:
   ```sh
   systemctl status seed-secrets-check.timer
   journalctl -u seed-secrets-check --since yesterday
   cat /var/lib/seed-secrets/seed-secrets.prom
   ```
   indri (the launchd log is the `StandardOutPath` of the daemon; the
   metric file is in the node_exporter textfile dir):
   ```sh
   sudo launchctl print system/mcquack.eblume.seed-secrets-check
   cat /opt/homebrew/var/node_exporter/textfile/seed-secrets.prom
   ```

3. **Re-run the check by hand as root** on the host:
   ```sh
   systemctl start seed-secrets-check          # ringtail
   sudo launchctl kickstart -k system/mcquack.eblume.seed-secrets-check  # indri
   ```
   (The job runs exactly what the schedule does. To refresh the `ok` gauge
   after a manual fix, run the same command again.)

4. **Confirm the metric is visible**: query `seed_secrets_check_ok` (and the
   timestamp gauge) in Grafana/Prometheus, for the affected `cluster`.

## Common Causes

- **Drifted file or stray file** — the failing line in the journal names it.
- **indri: hostname is not `indri`** — the `--local` probe requires the
  machine's `hostname` to equal exactly `indri`; otherwise the job writes
  `seed_secrets_check_ok 0` (a red metric, by design).
- **`/etc/blumeops` checkout missing** — the unit's
  `ConditionPathExists` on `nixos/ringtail/secrets.json` then silently skips,
  so the alerts go stale/red rather than the unit failing at boot.
- **The run is offline by design** — Python and its deps come from the nix
  store, so a red run is never a network/PyPI failure: the journal shows the
  check's own output (or a nix store problem, which `nix-store --verify`
  investigates).
- **Timer disabled** — `systemctl is-enabled seed-secrets-check.timer`
  (wanted by `timers.target`; `Persistent=true` catches up missed calendar
  fires, the boot leg `OnBootSec=15min` covers the never-fired case).

## Recovery

Fix the drift from gilbert — `mise run seed-secrets ringtail` (biometric
`op`, ssh) or `mise run seed-secrets indri` — then re-run the check on the
host (see step 3) and confirm `seed_secrets_check_ok 1` in the metric file.
A generation-owned file that legitimately lives in a managed dir is declared
in that dir's `expected_peers` (see [[seed-secrets]]), not left as a stray.

## Related

- [[seed-secrets]] — the task, and the manifests it owns
- [[runbook-textfile-stale]] — the indri textfile staleness runbook
- [[declared-state-files]] — the declared-state convention
