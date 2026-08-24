# Nix-built Grafana dashboard sidecar (kiwigrid k8s-sidecar) for ringtail
# (amd64), phase 3 of [[retire-minikube]].
#
# Upstream's src-layout installs the files under src/ as flat top-level
# modules ("python -m sidecar" runs src/sidecar.py), so instead of a pip
# install this copies the modules to /app and runs sidecar.py directly —
# the transmission-exporter pattern.
#
# Dependency versions come from nixpkgs rather than upstream's exact
# pins (kubernetes 33.x vs ==32.0.1, python-json-logger 3.3 vs ==4.1.0);
# logfmter is absent from nixpkgs and built from PyPI here. The argparse
# pin is a stdlib relic and dropped.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.10.1";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/kiwigrid-grafana-sidecar.git";
    rev = "2.10.1";
    hash = "sha256-UyX8IWfqlMQvbPv9sEPz5YD/uugU0IkyldPLHxpWr2g=";
  };

  logfmter = pkgs.python3Packages.buildPythonPackage rec {
    pname = "logfmter";
    version = "0.0.12";
    pyproject = true;
    build-system = [ pkgs.python3Packages.setuptools ];
    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-lY0OG+IVYhRRhF+V+OMmYNjadgpLzY7MVWSgx5Vwxnk=";
    };
    doCheck = false;
  };

  python = pkgs.python3.withPackages (ps: [
    ps.kubernetes
    ps.requests
    ps.python-json-logger
    logfmter
  ]);

  app = pkgs.runCommand "grafana-sidecar-app" { } ''
    mkdir -p $out/app
    cp ${src}/src/*.py $out/app/
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/grafana-sidecar";

  contents = [
    python
    app
    pkgs.cacert
  ];

  config = {
    Cmd = [ "${python}/bin/python" "-u" "/app/sidecar.py" ];
    Env = [
      "PYTHONUNBUFFERED=1"
      "PYTHONPATH=/app"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/app";
    User = "65534:65534";
  };
}
