# Nix-built frigate-notify — polls Frigate webapi and pushes alerts to ntfy.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.5.4";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/frigate-notify.git";
    rev = "v${version}";
    hash = "sha256-c/QOSQNNJ+ElMDm45lBOsru/ujBhCWethiRefj3hBOk=";
  };

  frigate-notify = pkgs.buildGoModule {
    inherit src version;
    pname = "frigate-notify";

    vendorHash = "sha256-Ho9oaK01wJDPf3ufV2klV1dG4qFNVNJkWmWvEgAy10s=";

    doCheck = false;
    subPackages = [ "." ];

    # `goolm` swaps the matrix crypto backend from libolm (CGO) to pure-Go olm,
    # avoiding the libolm.h dependency. Our deployment doesn't use matrix, but
    # the package is imported unconditionally.
    tags = [ "goolm" ];

    ldflags = [ "-s" "-w" ];

    meta = with pkgs.lib; {
      description = "Bridge between Frigate NVR events and notification services";
      homepage = "https://github.com/0x2142/frigate-notify";
      license = licenses.mit;
      mainProgram = "frigate-notify";
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/frigate-notify";
  contents = [
    frigate-notify
    pkgs.cacert
    pkgs.tzdata
  ];

  # Upstream Dockerfile expects WORKDIR=/app (config at ./config.yml, logfile at
  # ./log/app.log via lumberjack). Create /app world-writable so nonroot can
  # write logs; the config is mounted in from a ConfigMap.
  extraCommands = ''
    mkdir -p app
    chmod 1777 app
  '';

  config = {
    Entrypoint = [ "${frigate-notify}/bin/frigate-notify" ];
    WorkingDir = "/app";
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "8000/tcp" = { };
    };
    User = "65534";
  };
}
