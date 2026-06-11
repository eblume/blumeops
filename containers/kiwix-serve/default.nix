# Nix-built kiwix-serve for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# nixpkgs' kiwix-tools lags (3.7.0-unstable vs our deployed 3.8.2), so this
# keeps the Dagger build's approach: the official prebuilt static binary
# from the Kiwix mirror, pinned by hash — same 3.8.2, no version change.
# busybox provides /bin/sh for the deployment's glob-expanding command;
# dumb-init stays as PID 1 (sh does not exec kiwix-serve).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.8.2";

  kiwix-tools = pkgs.runCommand "kiwix-tools-${version}" { } ''
    mkdir -p $out/bin
    tar -xzf ${pkgs.fetchurl {
      url = "https://mirror.download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-${version}.tar.gz";
      hash = "sha256-sK6Y3TRKoEaaFatC/v9tWq+3lUGoL7TiZHx0sHMSOBU=";
    }} -C $out/bin --strip-components 1
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/kiwix-serve";

  contents = [
    kiwix-tools
    pkgs.dumb-init
    pkgs.busybox
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${pkgs.dumb-init}/bin/dumb-init" "--" ];
    Cmd = [
      "/bin/sh"
      "-c"
      "echo 'Use: kiwix-serve [options] <zim-files>' && kiwix-serve --help"
    ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "80/tcp" = { };
    };
    User = "1000";
  };
}
