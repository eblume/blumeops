# Nix-built kubectl utility image for ringtail (amd64), phase 1 of
# [[retire-minikube]]. Used by the kiwix zim-watcher CronJob (bash +
# kubectl + coreutils for ls/md5sum/sort/cut).
#
# nixpkgs kubectl tracks the containers/flake.lock pin (1.36.3 at the
# nixos-26.05 co-move); fine for `kubectl get/annotate/rollout` against k3s.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.36.3";
in

assert pkgs.kubectl.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/kubectl";

  contents = [
    pkgs.kubectl
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
  ];

  config = {
    Cmd = [ "${pkgs.kubectl}/bin/kubectl" "version" "--client" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    User = "65534";
  };
}
