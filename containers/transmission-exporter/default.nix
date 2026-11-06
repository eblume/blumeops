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

  # nixpkgs (nixos-26.05, the shared containers/flake.lock pin) ships older
  # client libs; take the current PyPI releases for this image only.
  python = (pkgs.python3.override {
    packageOverrides = self: super: {
      transmission-rpc = super.transmission-rpc.overridePythonAttrs (_: {
        version = "7.0.12";
        # The PyPI sdist ships no tests; pytest's "no tests ran" fails the check.
        doCheck = false;
        src = pkgs.fetchPypi {
          pname = "transmission_rpc";
          version = "7.0.12";
          hash = "sha256-tl8ZWia/PbeS+I7pMhGSkUQyH7w6TwGL9wKZljBPz6U=";
        };
      });
      prometheus-client = super.prometheus-client.overridePythonAttrs (_: {
        version = "0.26.0";
        src = pkgs.fetchPypi {
          pname = "prometheus_client";
          version = "0.26.0";
          hash = "sha256-BKkbz5Tiz3SkShqHTWUaLoU+01S26CLzt0h3UUZdXCs=";
        };
      });
    };
  }).withPackages (ps: [
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
