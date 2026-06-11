# Nix-built Grafana Loki for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build: same forge mirror, tag, build
# tags, and ldflags. Loki vendors its Go dependencies in-repo, so
# vendorHash is null. Runtime layout matches the Dockerfile (UID 10001,
# /loki working dir).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.6.7";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/loki.git";
    rev = "v${version}";
    hash = "sha256-4nu8ao0nGBMohf9b4uxkUzZwt1m1qbJ9YIKMF6Gh4TE=";
  };

  loki = pkgs.buildGoModule {
    inherit src version;
    pname = "loki";
    vendorHash = null; # repo vendors its dependencies

    doCheck = false;
    subPackages = [ "cmd/loki" ];
    env.CGO_ENABLED = 0;
    tags = [ "netgo" ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/grafana/loki/v3/pkg/util/build.Version=v${version}"
      "-X github.com/grafana/loki/v3/pkg/util/build.Branch=HEAD"
      "-X github.com/grafana/loki/v3/pkg/util/build.BuildUser=blumeops"
      "-X github.com/grafana/loki/v3/pkg/util/build.Revision=blumeops-build"
    ];

    meta.mainProgram = "loki";
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/loki";

  contents = [
    loki
    pkgs.cacert
    pkgs.tzdata
  ];

  fakeRootCommands = ''
    mkdir -p ./loki
    chown 10001:10001 ./loki
  '';

  config = {
    Entrypoint = [ "${loki}/bin/loki" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "3100/tcp" = { };
    };
    User = "10001";
  };
}
