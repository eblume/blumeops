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

  # The check itself is the vault-free `--check --local` leg of seed-secrets.
  # PATH must name bash (the local mode's `sh -c`), hostname (the probe
  # gates on it) and date (the timestamp); uv's python needs a sane PATH
  # and its CA bundle — systemd units do not source /etc/profile.
  check = pkgs.writeShellScript "seed-secrets-check" ''
    set -euo pipefail
    export PATH=${pkgs.bash}/bin:${pkgs.uv}/bin:${pkgs.coreutils}/bin:${pkgs.hostname}/bin:$PATH
    export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
    cd /etc/blumeops

    # Exit status is the metric, not the unit state: the wrapper always
    # exits 0 so a red check does not flap the unit — staleness means the
    # timer died, the ok gauge means the check failed. The check output
    # (paths, owner/group/mode — never values) stays in the journal, where
    # the runbook points when the alert fires.
    ok=0
    if uv run --script mise-tasks/seed-secrets ringtail --check --local; then
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
    # A Persistent boot catch-up can fire before the network is up; a cold
    # uv dep fetch then fails and writes a spurious ok=0.
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${check}";
      # First run fetches uv's PEP-723 deps on a cold cache; 100s default
      # would kill that.
      TimeoutStartSec = "10m";
    };
  };

  systemd.timers.seed-secrets-check = {
    description = "Weekly seed-secrets --check drift gate";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Sunday 05:30, ringtail local time (America/Los_Angeles — not UTC;
      # the earlier cadence discussion said 05:30 UTC, but the host TZ is
      # local and 05:30 local is the spirit).
      OnCalendar = "Sun *-*-* 05:30:00";
      RandomizedDelaySec = "15m";
      Persistent = true;
      AccuracySec = "5m";
    };
  };
}
