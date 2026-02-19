# Nix-built ntfy push notification server
# Replaces the multi-stage Dockerfile (Node + Go + Alpine) with nixpkgs ntfy-sh
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/ntfy";
  tag = "latest";

  contents = [
    pkgs.ntfy-sh
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${pkgs.ntfy-sh}/bin/ntfy" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "80/tcp" = { };
    };
    User = "65534";
  };
}
