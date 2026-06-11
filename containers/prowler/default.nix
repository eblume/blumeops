# Nix-built Prowler for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Wraps nixpkgs' prowler. VERSION NOTE: this is a step back from the
# Dockerfile build's 5.23.0 — nixpkgs lags, and 5.23 cannot be overridden
# onto 5.12's dep tree (5.23 eagerly imports alibabacloud/oci/cloudflare
# SDKs at CLI startup; none are packaged in nixpkgs). 5.12.3 carries the
# same cis_1.11_kubernetes framework we scan with. Re-bump via
# service-review when nixpkgs catches up.
#
# The Dockerfile also bundled trivy for image/IaC scans — those were
# retired earlier, so trivy (and its --ignorefile TODO) drop out here.
#
# python3+pyyaml is included for the cronjob's merge-mutelist
# initContainer (python3 -c "import yaml...").
{ pkgs ? import <nixpkgs> { } }:

let
  version = "5.12.3";
  app = pkgs.prowler;

  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/prowler";

  contents = [
    app
    python
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Cmd = [ "${app}/bin/prowler" "--help" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "HOME=/tmp"
    ];
    User = "65534";
  };
}
