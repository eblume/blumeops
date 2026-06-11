# Nix-built Grafana Tempo for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build: same forge mirror, tag, and
# ldflags. Tempo vendors its Go dependencies in-repo, so vendorHash is
# null. Runtime layout matches the Dockerfile (UID 10001, /var/tempo).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "2.10.3";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/tempo.git";
    rev = "v${version}";
    hash = "sha256-3c8I7a++PqY2omQHpNrdaCz6MKaCQ2shdkhHgaKWgZI=";
  };

  tempo = pkgs.buildGoModule {
    inherit src version;
    pname = "tempo";
    vendorHash = null; # repo vendors its dependencies

    doCheck = false;
    subPackages = [ "cmd/tempo" ];
    env.CGO_ENABLED = 0;

    ldflags = [
      "-s"
      "-w"
      "-X main.Version=v${version}"
      "-X main.Branch=HEAD"
      "-X main.Revision=blumeops-build"
    ];

    meta.mainProgram = "tempo";
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/tempo";

  contents = [
    tempo
    pkgs.cacert
    pkgs.tzdata
  ];

  fakeRootCommands = ''
    mkdir -p ./var/tempo
    chown 10001:10001 ./var/tempo
  '';

  config = {
    Entrypoint = [ "${tempo}/bin/tempo" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "3200/tcp" = { };
      "4317/tcp" = { };
      "4318/tcp" = { };
      "9095/tcp" = { };
    };
    User = "10001";
  };
}
