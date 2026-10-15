# Removes the retired cargo-installed heph bins (heph, hephd, heph-tui,
# heph-quickadd) from the spoke users' ~/.cargo/bin so they can't shadow the
# nix-store heph (eblume/blumeops#1541). Deletion is by name, not dir, so a
# future manual `cargo install heph` gets cleaned up at the next boot too.
{ pkgs, lib, ... }:
let
  bins = [ "heph" "hephd" "heph-tui" "heph-quickadd" ];
  binDirs = [ "/home/agent/.cargo/bin" "/home/eblume/.cargo/bin" ];
  cleanup = pkgs.writeShellScriptBin "heph-cargo-bin-cleanup" ''
    set -euo pipefail
    for dir in ${lib.concatStringsSep " " binDirs}; do
      # A symlinked bin dir must be skipped: the script runs as root, and
      # following the link would rm into whatever it points at.
      [ -d "$dir" ] && [ ! -L "$dir" ] || continue
      for b in ${lib.concatStringsSep " " bins}; do
        # -rf: a stale non-regular entry or a transient I/O error must not
        # fail the oneshot (it would re-run every boot).
        ${pkgs.coreutils}/bin/rm -rf -- "$dir/$b"
      done
    done
  '';
in
{
  systemd.services."heph-cargo-bin-cleanup" = {
    description = "Remove the retired cargo-installed heph bins from ~/.cargo/bin";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${cleanup}/bin/heph-cargo-bin-cleanup";
    };
  };
}
