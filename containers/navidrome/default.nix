# Nix-built Navidrome for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the three-stage Dagger build (Node UI + CGO Go backend + Alpine)
# with nixpkgs' navidrome, which ships the embedded UI and links taglib.
# ffmpeg is included explicitly for transcoding (belt and suspenders —
# nixpkgs wraps the binary with ffmpeg on PATH, but the runtime container
# should not depend on that wrapper detail).
#
# Self-pins nixos-unstable (mealie precedent): ringtail's stable nixpkgs
# (25.11) lags behind unstable. Navidrome migrates its SQLite schema forward
# automatically on startup, and 0.64.0 re-encodes every ID in a one-way
# migration; the daily ND_BACKUP_* snapshot plus borgmatic covers rollback.
# The version assertion makes nix-build fail if a pin bump changes the
# version unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504.tar.gz";
    sha256 = "177diqkiwphjyqpk2n6nisayx840x28ksvq99kkyi2xsn37fp4md";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "0.64.2";
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
