# Nix-built UnPoller for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# nixpkgs' unpoller lags badly, so this builds from the forge mirror at the
# pinned tag — the ntfy pattern.
#
# Self-pins nixos-26.05 (tempo/alloy precedent): v5.10.x's go.mod needs
# Go 1.27.4, and the containers flake.lock nixpkgs only carries go_1_27
# 1.27.1. Bumping containers/flake.lock would move every container.
{ }:

let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/0dc498bfe49baeb18b0f9891e800b53bb2603193.tar.gz";
    sha256 = "09m91kcd36jg2lvvrfy0qwk7frsjn84hfn497bax4rmcrfmj7zdk";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "5.10.1";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/unpoller.git";
    rev = "v${version}";
    hash = "sha256-MjEEf/p8ZS7Z46tvORQhLYaFNPpxrjv+SPiPXpAeKe0=";
  };

  unpoller = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
    inherit src version;
    pname = "unpoller";
    vendorHash = pkgs.lib.fakeHash;

    doCheck = false;
    subPackages = [ "." ];

    ldflags = [ "-s" "-w" ];

    meta.mainProgram = "unpoller";
  };
in

assert pkgs.go_1_27.version == "1.27.4";

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/unpoller";

  contents = [
    unpoller
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Cmd = [ "${unpoller}/bin/unpoller" "--config" "/etc/unpoller/up.conf" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "9130/tcp" = { };
    };
    User = "65534";
  };
}
