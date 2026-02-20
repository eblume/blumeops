# Nix-built Authentik identity provider
# Uses nixpkgs authentik package (ak entrypoint wrapping Go server + Python worker)
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/authentik";
  tag = "latest";

  contents = [
    pkgs.authentik
    pkgs.bashInteractive
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${pkgs.authentik}/bin/ak" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "9000/tcp" = { };
      "9443/tcp" = { };
    };
    User = "65534";
  };
}
