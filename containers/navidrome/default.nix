# Nix-built Navidrome for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the three-stage Dagger build (Node UI + CGO Go backend + Alpine)
# with nixpkgs' navidrome, which ships the embedded UI and links taglib.
# ffmpeg is included explicitly for transcoding (belt and suspenders —
# nixpkgs wraps the binary with ffmpeg on PATH, but the runtime container
# should not depend on that wrapper detail).
#
# Exact version match with the deployed Dockerfile build (0.61.1) — a true
# lift-and-shift, no migration concerns. The version assertion makes
# nix-build fail if a pin bump changes the version unexpectedly.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.61.1";
  app = pkgs.navidrome;
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/navidrome";

  contents = [
    app
    pkgs.ffmpeg-headless
    pkgs.cacert
    pkgs.tzdata
    # coreutils provides ls/cat so borgmatic on indri can discover and
    # stream navidrome's own DB backups out of the pod (see the borgmatic
    # role's k8s-file-dump helper). The base nix image ships no shell utils.
    pkgs.coreutils
  ];

  config = {
    Entrypoint = [ "${app}/bin/navidrome" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "4533/tcp" = { };
    };
    # Matches the deployment securityContext (runAsUser/fsGroup 1000) and
    # the ownership of the existing navidrome-data files.
    User = "1000";
  };
}
