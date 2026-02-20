# Nix-built Dex OIDC identity provider
# Uses nixpkgs dex-oidc package with Kubernetes CRD storage backend
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/dex";
  tag = "latest";

  contents = [
    pkgs.dex-oidc
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${pkgs.dex-oidc}/bin/dex" ];
    Cmd = [ "serve" "/etc/dex/cfg/config.yaml" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "5556/tcp" = { };
    };
    User = "65534";
  };
}
