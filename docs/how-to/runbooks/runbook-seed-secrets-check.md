---
title: "Runbook: Seed Secrets Check"
modified: 2026-10-13
last-reviewed: 2026-10-13
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Seed Secrets Check

**Alert names:** `SeedSecretsCheckFailed`, `SeedSecretsCheckStale`

The weekly vault-free drift gate for the on-host secret files declared in
`nixos/ringtail/secrets.json` — the seven files ringtail's nix config
references by path. Each week a root systemd timer on the host itself runs
`uv run --script /etc/blumeops/mise-tasks/seed-secrets ringtail --check
--local`, which verifies every declared file's presence/owner/group/mode and
scans the managed directories for stray files (see [[seed-secrets]] and
eblume/blumeops#1524). The gate is host-local because the CI runner has no
ssh+sudo route back to ringtail; `--local` also needs no vault and no
1Password.

The check's verdict is written to `/var/lib/seed-secrets/seed-secrets.prom`
(two gauges — `seed_secrets_check_ok` and
`seed_secrets_check_timestamp_seconds`), scraped by ringtail's Alloy textfile
collector and remote-written to the in-cluster Prometheus with
`cluster="ringtail"`. The two alerts:

- **`SeedSecretsCheckFailed`** — `seed_secrets_check_ok == 0` for 15m: the
  last run was red (drifted file, stray file, or an `UNKNOWN` — a check
  that cannot see is a failure).
- **`SeedSecretsCheckStale`** — last timestamp older than 8 days (7d timer +
  1d margin), or no series at all: the timer never ran. A *missing* series
  is exactly this failure, so the stale rule alerts on NoData.

The unit itself always exits 0 — a red check must not flap the unit; the
metric and these rules carry the state.

## Diagnostic Steps

1. **Which alert fired?**
   - `SeedSecretsCheckFailed`: the check ran and found drift — read the
     journal for what.
   - `SeedSecretsCheckStale`: the timer never ran or its output is stale.

2. **Check the timer and the last run** on ringtail:
   ```sh
   systemctl status seed-secrets-check.timer
   journalctl -u seed-secrets-check --since yesterday
   cat /var/lib/seed-secrets/seed-secrets.prom
   ```

3. **Re-run the check by hand as root** on ringtail:
   ```sh
   cd /etc/blumeops && uv run --script mise-tasks/seed-secrets ringtail --check --local
   ```
   (The timer run's output lands in the unit journal, so `journalctl` and
   this command show the same lines. To refresh the `ok` gauge after a
   manual fix, run `systemctl start seed-secrets-check`.)

4. **Confirm the metric is visible**: query `seed_secrets_check_ok` (and the
   timestamp gauge) in Grafana/Prometheus, `cluster="ringtail"`.

## Common Causes

- **Drifted file or stray file** — the failing line in the journal names it.
- **`/etc/blumeops` checkout missing** — the unit's
  `ConditionPathExists` on `nixos/ringtail/secrets.json` then silently skips,
  so the alerts go stale/red rather than the unit failing at boot.
- **uv/python dependency fetch failure** — first run after a deploy fetches
  its deps on a cold cache; the wrapper's 10m `TimeoutStartSec` absorbs a
  slow fetch, while a persistent failure (network, power) writes `ok 0` and
  stays red until the next weekly run. `journalctl -u seed-secrets-check`
  shows the fetch error.
- **Timer disabled** — `systemctl is-enabled seed-secrets-check.timer`
  (wanted by `timers.target`; `Persistent=true` catches up after downtime).

## Recovery

Fix the drift from gilbert — `mise run seed-secrets ringtail` (biometric
`op`, ssh) — then re-run the check on ringtail:
`systemctl start seed-secrets-check`, and confirm
`seed_secrets_check_ok 1` in the metric file.

## Related

- [[seed-secrets]] — the task, and the manifests it owns
- [[runbook-textfile-stale]] — the indri textfile staleness runbook
- [[declared-state-files]] — the declared-state convention
