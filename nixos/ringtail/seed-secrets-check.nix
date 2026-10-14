# Weekly vault-free drift gate for the on-host secret files declared in
# nixos/ringtail/secrets.json. Runs seed-secrets --check --local as root via
# a systemd timer: the CI runner has no ssh+sudo route back to the box, so
# the gate lives on the host it guards (vault-free, needs no `op`).
# State rides a textfile metric (ok + timestamp) scraped by ringtail's Alloy,
# with Grafana rules SeedSecretsCheckFailed / SeedSecretsCheckStale.
{ config, pkgs, lib, ... }:

let
  metricDir = "/var/lib/seed-secrets";
  metricFile = "${metricDir}/seed-secrets.prom";

  # Nix-built Python with the script's PEP-723 deps (rich, typer), so the
  # weekly run resolves nothing from the network — a uv fetch as root at
  # check time would make a drift check depend on the network and on PyPI.
  # Versions follow nixpkgs, not the PEP-723 pins: both deps are stable
  # CLIs, and a breaking change makes the check red, not wrong.
  checkPy = pkgs.python3.withPackages (ps: with ps; [ ps.rich ps.typer ]);

  # The check itself is the vault-free `--check --local` leg of seed-secrets.
  # PATH must name sh (the local mode's `sh -c`), hostname (the probe gates
  # on it) and the coreutils it shells out to (stat, sha256sum, id, uname,
  # date, mv); systemd units do not source /etc/profile.
  check = pkgs.writeShellScript "seed-secrets-check" ''
    set -euo pipefail
    export PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.hostname}/bin:$PATH
    cd /etc/blumeops

    # Exit status is the metric, not the unit state: the wrapper always
    # exits 0 so a red check does not flap the unit — staleness means the
    # timer died, the ok gauge means the check failed. The check output
    # (paths, owner/group/mode — never values) stays in the journal, where
    # the runbook points when the alert fires.
    ok=0
    if ${checkPy}/bin/python3 mise-tasks/seed-secrets ringtail --check --local; then
      ok=1
    fi

    ts=$(date +%s)
    tmp="${metricDir}/seed-secrets.prom.tmp"
    {
      echo "# HELP seed_secrets_check_ok 1 when the last seed-secrets --check passed"
      echo "# TYPE seed_secrets_check_ok gauge"
      echo "seed_secrets_check_ok $ok"
      echo "# HELP seed_secrets_check_timestamp_seconds Unix time the last seed-secrets --check ran"
      echo "# TYPE seed_secrets_check_timestamp_seconds gauge"
      echo "seed_secrets_check_timestamp_seconds $ts"
    } >"$tmp"
    mv -f "$tmp" ${metricFile}
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${metricDir} 0755 root root -"
  ];

  systemd.services.seed-secrets-check = {
    description = "Vault-free seed-secrets --check drift gate (weekly)";
    restartIfChanged = false;
    unitConfig.ConditionPathExists = "/etc/blumeops/nixos/ringtail/secrets.json";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${check}";
      # The run is offline and short (a handful of stat/sha256 commands);
      # the default 90s oneshot timeout is deliberate — an overlong run
      # should fail loud, not drag on.
    };
  };

  systemd.timers.seed-secrets-check = {
    description = "Weekly seed-secrets --check drift gate";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Weekly leg: Sunday 05:30, ringtail local time (America/Los_Angeles —
      # not UTC; the earlier cadence discussion said 05:30 UTC, but the host
      # TZ is local and 05:30 local is the spirit).
      OnCalendar = "Sun *-*-* 05:30:00";
      RandomizedDelaySec = "15m";
      # Boot leg: the metric file does not exist until the first run, and
      # SeedSecretsCheckStale is noDataState Alerting, so a fresh NixOS build
      # or reboot would page within an hour otherwise. Persistent=true only
      # covers missed calendar fires, not a never-fired timer, so the first
      # run needs its own trigger. A boot run + the weekly OnCalendar is the
      # existing ringtail pattern (ringtail-apply-watcher); a reboot that
      # crosses a missed calendar fire can double-run the unit — idempotent
      # and offline, so harmless. The metric timestamp then keeps refreshing
      # weekly, so the stale rule still catches a dead timer between reboots
      # (eblume/blumeops#1524).
      OnBootSec = "15min";
      Persistent = true;
      AccuracySec = "5m";
    };
  };
}
