# Nix-built Grafana Tempo for ringtail (amd64), phase 3 of [[retire-minikube]].
#
# Lift-and-shift of the Dockerfile build: same forge mirror, tag, and
# ldflags. Tempo vendors its Go dependencies in-repo, so vendorHash is
# null. Runtime layout matches the Dockerfile (UID 10001, /var/tempo).
#
# Self-pins nixos-26.05 (mealie precedent): v3.1.x's go.mod needs Go 1.27.3,
# and the containers flake.lock nixpkgs only carries go_1_27 1.27.1.
# Bumping containers/flake.lock would move every container, so tempo alone
# pins here. The version assertion makes nix-build fail if a pin bump
# changes the toolchain version unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/f1e5c356f35d07e7b71a6b5e6c9338e0b029e0c0.tar.gz";
    sha256 = "sha256-qXFIqA6FCcx7XeDzw0ZNlkDT9UiCzrNDwK8RuU8RcHM=";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "3.1.1";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/tempo.git";
    rev = "v${version}";
    hash = pkgs.lib.fakeHash;
  };

  tempo = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
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

assert tempo.go.version == "1.27.4";

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
