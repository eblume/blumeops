# The two heph spokes used to `cargo install` their binaries into
# ~/.cargo/bin; the switch to the nix-store heph package (eblume/blumeops#1541)
# left those files on disk, where they still shadow the store bins for any
# shell that keeps ~/.cargo/bin on PATH. This one-shot removes exactly the
# four heph bin names from both users' cargo bin dirs (everything else in
# those dirs is untouched), and is a no-op on later boots once they are gone.
{ pkgs, lib, ... }:
let
  bins = [ "heph" "hephd" "heph-tui" "heph-quickadd" ];
  binDirs = [ "/home/agent/.cargo/bin" "/home/eblume/.cargo/bin" ];
  cleanup = pkgs.writeShellScriptBin "heph-cargo-bin-cleanup" ''
    set -euo pipefail
    for dir in ${lib.concatStringsSep " " binDirs}; do
      [ -d "$dir" ] || continue
      for b in ${lib.concatStringsSep " " bins}; do
        ${pkgs.coreutils}/bin/rm -f "$dir/$b"
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
