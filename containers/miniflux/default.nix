# Nix-built Miniflux for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the from-source Dagger build (clone_from_forge + go_build) with
# nixpkgs' miniflux — a single static-ish Go binary with the web UI
# embedded, so this is the simplest possible wrap.
#
# Version note: nixos-25.11 (stable) is EOL and frozen at 2.3.1, so waiting
# for stable to catch up is dead. Self-pins nixos-unstable instead (mealie/
# navidrome precedent), reusing the same pinned rev+hash as
# containers/navidrome/default.nix and containers/mealie/default.nix (no
# new hash fetch needed). Bumped 2026-07-22: 2.3.1 -> 2.3.2, a single patch
# release — a security fix (prevents username enumeration via login timing)
# plus search improvements. It also raises the minimum supported PostgreSQL
# to 11; this deployment runs PG 18, so that's not a blocker. 2.3.0's
# tombstone-table migration (drops the `removed` entry status, applied via
# RUN_MIGRATIONS=1 on first boot) already landed for the 2.3.1 cutover and
# is unaffected by this bump; the minikube source database remains
# untouched after the original cutover dump, so rollback is still "scale
# the minikube deployment back up against its own (pre-migration) DB".
# The version assertion makes nix-build fail if a pin bump changes the
# version unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "2.3.2";
  app = pkgs.miniflux;
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/miniflux";

  contents = [
    app
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${pkgs.lib.getExe app}" ];
    Env = [
      "LISTEN_ADDR=0.0.0.0:8080"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
    };
    User = "65534";
  };
}
