# Publish EVE Online game state into heph as tasks, hourly.
#
# The friction in EVE is not difficulty, it is remembering: PI extractors expire
# on their own schedule, industry jobs finish while you are asleep, market orders
# get undercut. All of it is queryable from ESI, and heph already runs the rest
# of Erich's life as a recurring-chore engine — so the game's obligations get
# published into the same "what is next?" ranking as everything else. The
# motivating case: a manufacturing job finished 2026-07-18 and sat undelivered
# for 12 days because nothing surfaced it.
#
# The sync itself lives in the myeve repo (scripts/heph-sync/eve_chores.py) and
# is documented there. This module is only the schedule.
{ config, pkgs, lib, ... }:

let
  home = "/home/eblume";
  cargoBin = "${home}/.cargo/bin";
  repo = "${home}/code/personal/myeve";
  script = "${repo}/scripts/heph-sync/eve_chores.py";

  # ESI tokens live in ${repo}/secrets (gitignored). Deliberately NOT a blumeops
  # secret: this is a game account, it is worth nothing operationally, and
  # routing it through 1Password/external-secrets would imply a custody it does
  # not deserve. If the refresh token is revoked the script exits non-zero and
  # the unit fails loudly rather than publishing a stale chore list.
  token = "${repo}/secrets/esi-token.json";

  # The script reads out of the working tree on purpose. Packaging myeve as a
  # derivation buys nothing while the tool changes weekly, and would mean a
  # blumeops deploy for every collector tweak. Revisit if it stabilises.
  #
  # uv resolves the script's PEP-723 inline deps (httpx) on first run and caches
  # them under ~/.cache/uv. `heph` comes from ~/.cargo/bin, installed by the
  # eblume-heph-install oneshot in heph-eblume.nix.
  sync = pkgs.writeShellScript "myeve-heph-sync" ''
    set -euo pipefail
    export HOME=${home}
    export PATH=${cargoBin}:${pkgs.uv}/bin:$PATH
    # systemd units do not source /etc/profile, so the session-wide cert env
    # never reaches here. httpx ships certifi, but uv's own index fetches want
    # a system bundle on a cold cache.
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    cd ${repo}
    exec uv run --script ${script} "$@"
  '';
in
{
  # A systemd USER service, and that is load-bearing — the same constraint
  # documented at length in heph-eblume.nix. `heph` reaches `hephd` over a
  # socket under $XDG_RUNTIME_DIR (/run/user/1000/heph/hephd.sock). A system
  # service has no XDG_RUNTIME_DIR, would bind the ~/.local/share fallback, and
  # would never meet eblume's spoke. `users.users.eblume.linger` is already true
  # in heph-eblume.nix, which is what keeps the user manager alive from boot.
  systemd.user.services.myeve-heph-sync = {
    description = "Publish EVE Online game state into heph as tasks";
    unitConfig = {
      ConditionUser = "eblume";
      # Skip cleanly (not failed) when the pieces are not there: no heph CLI
      # yet, no myeve checkout, no ESI token, or the spoke still starting up
      # after boot. A skipped tick costs an hour; a failed one costs an hour
      # and a red unit. %t is XDG_RUNTIME_DIR.
      ConditionPathExists = [
        "${cargoBin}/heph"
        script
        token
        "%t/heph/hephd.sock"
      ];
    };
    serviceConfig = {
      Type = "oneshot";
      # --apply is write mode. Every task it files lands under the MyEVE
      # project and carries a `myeve-key:` line, and it only ever closes tasks
      # carrying that line — hand-filed tasks are invisible to it.
      ExecStart = "${sync} --apply";
      Nice = 10;
    };
    # The spoke owns the socket. If it is restarting, the condition above skips
    # this tick rather than failing it.
    after = [ "eblume-heph-spoke.service" ];
  };

  systemd.user.timers.myeve-heph-sync = {
    description = "Periodic EVE -> heph chore sync";
    unitConfig.ConditionUser = "eblume";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # PI extractor cycles run for hours and industry jobs for days, so a
      # tighter loop only burns ESI rate limit for no added warning. Hourly sits
      # well inside the shortest deadline that matters.
      OnCalendar = "hourly";
      RandomizedDelaySec = "10m";     # do not hammer ESI on the hour
      Persistent = true;              # catch up after the host has been off
      AccuracySec = "5m";
    };
  };
}
