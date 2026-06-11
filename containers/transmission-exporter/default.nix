# Nix-built Transmission exporter for ringtail (amd64), phase 1 of
# [[retire-minikube]].
#
# The exporter is our own exporter.py (collect-on-scrape via
# prometheus-client + transmission-rpc). The Dagger build resolved deps
# at runtime with uv; here they're a pinned python environment, so the
# uv-script shebang/metadata in exporter.py is bypassed — python runs the
# script directly.
{ pkgs ? import <nixpkgs> { } }:

let
  # our exporter.py's own version (continues the Dagger build's numbering)
  version = "1.0.1";

  python = pkgs.python3.withPackages (ps: [
    ps.prometheus-client
    ps.transmission-rpc
  ]);

  exporter = pkgs.runCommand "transmission-exporter-app" { } ''
    mkdir -p $out/app
    cp ${./exporter.py} $out/app/exporter.py
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/transmission-exporter";

  contents = [
    python
    exporter
    pkgs.cacert
  ];

  config = {
    Cmd = [ "${python}/bin/python" "/app/exporter.py" ];
    Env = [
      "PYTHONUNBUFFERED=1"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    ExposedPorts = {
      "19091/tcp" = { };
    };
    User = "65534";
  };
}
