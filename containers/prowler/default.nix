# Nix-built Prowler for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Lift-and-shift of nixpkgs' prowler — the version assertion fails the
# build if a nixpkgs bump moves the package, so service-review drives
# re-bumps. Image/IaC scans (and the trivy they needed) were retired,
# so this ships the CLI only.
#
# python3+pyyaml is included for the cronjob's merge-mutelist
# initContainer (python3 -c "import yaml...").
{ pkgs ? import <nixpkgs> { } }:

let
  version = "5.39.1";
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
