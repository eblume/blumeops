# Nix-built OpenRouter provider-bill exporter for ringtail (eblume/blumeops#1981).
#
# Homegrown single-file exporter (the transmission-exporter pattern): the
# script here, a pinned python environment, deps from the nixpkgs pin in
# containers/flake.lock.
{ pkgs ? import <nixpkgs> { } }:

let
  # build-container greps this for the image tag
  version = "0.1.0";

  python = pkgs.python3.withPackages (ps: [
    ps.prometheus-client
  ]);

  exporter = pkgs.runCommand "openrouter-exporter-app" { } ''
    mkdir -p $out/app
    cp ${./exporter.py} $out/app/exporter.py
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/openrouter-exporter";

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
      "9102/tcp" = { };
    };
    User = "65534";
  };
}
