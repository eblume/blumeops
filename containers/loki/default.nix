# Nix-built Grafana Loki for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build: same forge mirror, tag, build
# tags, and ldflags. Loki vendors its Go dependencies in-repo, so
# vendorHash is null. Runtime layout matches the Dockerfile (UID 10001,
# /loki working dir).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.7.8";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/loki.git";
    rev = "v${version}";
    hash = "sha256-H+4qSXf0gZL2RCf5o4v4V3/ozLVESdhy0QDEpXbAGuc=";
  };

  # Loki 3.7.x go.mod requires go >= 1.26.5; the builder's default
  # buildGoModule is still on go 1.25.
  buildGo126Module = pkgs.buildGoModule.override { go = pkgs.go_1_26; };

  loki = buildGo126Module {
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
