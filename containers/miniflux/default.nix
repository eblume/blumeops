# Nix-built Miniflux for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the from-source Dagger build (clone_from_forge + go_build) with
# nixpkgs' miniflux — a single static-ish Go binary with the web UI
# embedded, so this is the simplest possible wrap.
#
# Self-pins nixos-unstable (stable is EOL), reusing the same pinned rev+hash
# as containers/navidrome/default.nix and containers/mealie/default.nix.
# The version assertion makes nix-build fail if a pin bump changes the
# version unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/31ecbaca1bdefa45dffc409f0250bd8039ea0010.tar.gz";
    sha256 = "1lzqyss0pznfh3az0llsp4a7c8gqcyq8wf96fnl5cnh5b3lic6kn";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "2.3.4";
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
