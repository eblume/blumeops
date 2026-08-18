# Watch the Skagit CCE course catalog for a new ceramics class.
#
# Erich wants to know as soon as the college lists a new ceramics class in
# this category, and it adds classes without notice. The catalog category
# (catId=47) is a public
# ASPX page that lists its classes server-side; each class carries an
# "Item Number" (the canonical CCE class id). This module fetches the page on a
# schedule, diffs the item numbers it has seen before, and files a RED heph
# task into eblume's heph the first time a class whose title looks like
# ceramics appears — so it ranks in his "what is next?" like anything else.
#
# The watch logic lives in skagit-cce-watch.py (read raw, so no Nix string
# escaping to keep in sync). This module is only the schedule + packaging.
#
# Identity / alert policy (see the script for the full rationale):
#   * keyed on the Item Number (a class is new when its item number is unseen)
#   * first run establishes a baseline and files nothing (no wake-up for a
#     course that is already listed)
#   * a new ceramics-looking class files a red task; a new non-ceramics class
#     is recorded but files nothing
#   * a zero-course parse fails the tick and leaves state untouched, so a page
#     or parse regression goes red in the journal instead of wiping the
#     baseline or flooding alerts
{ config, pkgs, lib, ... }:

let
  home = "/home/eblume";
  cargoBin = "${home}/.cargo/bin";
  # Real dir under eblume's home (not /nix/store), so it survives rebuilds and
  # holds the known-item-number baseline across runs.
  stateDir = "${home}/.local/state/skagit-cce-watch";

  # Stdlib-only script; pkgs.python3 is the interpreter (no site-packages deps).
  watch = pkgs.writeText "skagit-cce-watch.py"
    (builtins.readFile ./skagit-cce-watch.py);

  # Thin runner: set the user env a systemd user unit would not otherwise have
  # (HOME, PATH to the cargo-installed heph CLI) and the state/project knobs,
  # then exec the script.
  run = pkgs.writeShellScript "skagit-cce-watch" ''
    set -euo pipefail
    export HOME=${home}
    export PATH=${cargoBin}:$PATH
    export SKAGIT_CCE_STATE_DIR=${stateDir}
    export SKAGIT_CCE_PROJECT="Ceramics"
    exec ${pkgs.python3}/bin/python3 ${watch}
  '';
in
{
  # A systemd USER service (not system) — the same load-bearing constraint as
  # eblume-heph-spoke and myeve-heph-sync: `heph` reaches `hephd` over a socket
  # under $XDG_RUNTIME_DIR (/run/user/1000/heph/hephd.sock), which only the user
  # manager provides. eblume.linger is already true (heph-eblume.nix).
  systemd.user.services.skagit-cce-watch = {
    description = "Watch Skagit CCE catalog for a new ceramics class";
    unitConfig = {
      ConditionUser = "eblume";
      # Skip cleanly (not failed) when the pieces are not there: no heph CLI
      # yet, or the spoke still starting up after boot. A skipped tick costs a
      # day; a failed one costs a day and a red unit. %t is XDG_RUNTIME_DIR.
      ConditionPathExists = [
        "${cargoBin}/heph"
        "%t/heph/hephd.sock"
      ];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${run}";
      Nice = 10;
    };
    # The spoke owns the socket; if it is restarting, the condition above skips
    # this tick rather than failing it.
    after = [ "eblume-heph-spoke.service" ];
  };

  systemd.user.timers.skagit-cce-watch = {
    description = "Periodic Skagit CCE ceramics watch";
    unitConfig.ConditionUser = "eblume";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Erich wants a new ceramics class surfaced promptly, so this runs at
      # least hourly rather than daily. One small GET an hour is negligible,
      # and the jitter keeps the fetches from landing at the same instant.
      # Persistent guarantees a catch-up tick after the host has been off.
      OnCalendar = "hourly";
      RandomizedDelaySec = "10m";
      Persistent = true;
      AccuracySec = "5m";
    };
  };
}
