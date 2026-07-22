# Nix-built Navidrome for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the three-stage Dagger build (Node UI + CGO Go backend + Alpine)
# with nixpkgs' navidrome, which ships the embedded UI and links taglib.
# ffmpeg is included explicitly for transcoding (belt and suspenders —
# nixpkgs wraps the binary with ffmpeg on PATH, but the runtime container
# should not depend on that wrapper detail).
#
# Self-pins nixos-unstable (mealie precedent): ringtail's stable nixpkgs
# (25.11) is stuck at 0.61.1, while unstable carries 0.63.2 — past the
# v0.62.0 security fixes (cross-account share disclosure, authorization
# checks, transcode-DoS cap). Navidrome migrates its SQLite schema forward
# automatically on startup; the daily ND_BACKUP_* snapshot plus borgmatic
# covers rollback. The version assertion makes nix-build fail if a pin
# bump changes the version unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "0.63.2";
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
