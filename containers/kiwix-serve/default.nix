# Nix-built kiwix-serve for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# busybox provides /bin/sh for the deployment's glob-expanding command;
# dumb-init stays as PID 1 (sh does not exec kiwix-serve).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "3.8.2";
in

assert pkgs.kiwix-tools.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/kiwix-serve";

  contents = [
    pkgs.kiwix-tools
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
