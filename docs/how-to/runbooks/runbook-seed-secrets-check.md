---
title: "Runbook: Seed Secrets Check"
modified: 2026-10-14
last-reviewed: 2026-10-14
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
the `/etc/blumeops/mise-tasks/seed-secrets` script in a nix-built Python
env (rich + typer, the script's declared deps — the run is fully offline
from the store): `--check --local` verifies every declared file's
presence/owner/group/mode and scans the managed directories for stray files
(see [[seed-secrets]] and
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
  1d margin). The timer also fires once at boot (`OnBootSec=15min`), so the
  series exists within an hour of any fresh deploy or reinstall; an
  `absent()` branch in the query covers the window before that first run
  (and a never-fired timer), so a missing series still alerts.

The unit itself always exits 0 — a red check must not flap the unit; the
metric and these rules carry the state.

## Diagnostic Steps

1. **Which alert fired?**
   - `SeedSecretsCheckFailed`: the check ran and found drift — read the
     journal for what.
   - `SeedSecretsCheckStale`: the timer never ran (including the boot run
    after a fresh deploy), or its output is stale.

2. **Check the timer and the last run** on ringtail:
   ```sh
   systemctl status seed-secrets-check.timer
   journalctl -u seed-secrets-check --since yesterday
   cat /var/lib/seed-secrets/seed-secrets.prom
   ```

3. **Re-run the check by hand as root** on ringtail:
   ```sh
   systemctl start seed-secrets-check
   ```
   (The unit runs exactly what the timer does; its output lands in the unit
   journal. To refresh the `ok` gauge after a manual fix, run the same
   command again.)

4. **Confirm the metric is visible**: query `seed_secrets_check_ok` (and the
   timestamp gauge) in Grafana/Prometheus, `cluster="ringtail"`.

## Common Causes

- **Drifted file or stray file** — the failing line in the journal names it.
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
`op`, ssh) — then re-run the check on ringtail:
`systemctl start seed-secrets-check`, and confirm
`seed_secrets_check_ok 1` in the metric file.

## Related

- [[seed-secrets]] — the task, and the manifests it owns
- [[runbook-textfile-stale]] — the indri textfile staleness runbook
- [[declared-state-files]] — the declared-state convention
