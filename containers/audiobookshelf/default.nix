# Nix-built Audiobookshelf for ringtail (amd64) — serves the audiobooks that
# live in the sifaka music share (/volume1/music/Audiobooks, eblume/blumeops#1120).
#
# Self-pins nixos-unstable (navidrome precedent): the fleet pin (navidrome /
# mealie / miniflux) predates the 2.36.0 package, so this pins a newer
# unstable that also carries the "downgrade ffmpeg from 9 to 8" fix. The
# version assertion makes nix-build fail if a pin bump changes the version
# unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ef34387ddd751e1ab8857adf4676492d32eb24ec.tar.gz";
    sha256 = "0wfp59yxnxram68zv0g1jpy0bldls5fph1kxpm216fcrqbnhl8bs";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "2.36.0";
  app = pkgs.audiobookshelf;
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/audiobookshelf";

  contents = [
    # The nixpkgs derivation wraps the binary in a shell wrapper that bakes
    # FFMPEG_PATH/FFPROBE_PATH into store paths already in the closure, so
    # unlike navidrome no separate ffmpeg dependency is needed.
    app
    pkgs.cacert
    pkgs.tzdata
    # coreutils provides ls/cat so borgmatic on indri can discover and
    # stream audiobookshelf's scheduled backup zips out of the pod (see the
    # borgmatic role's k8s-file-dump helper). The base nix image ships no
    # shell utils.
    pkgs.coreutils
  ];

  config = {
    # The wrapper computes CONFIG_PATH/METADATA_PATH as "$(pwd)/config" and
    # "$(pwd)/metadata"; WorkingDir "/" puts those at /config and /metadata.
    WorkingDir = "/";
    # The wrapper overrides the PORT env var, so the port is a CLI arg.
    # ringtail's k3s lets non-root pods bind below 1024 (kiwix / ntfy
    # precedent).
    Entrypoint = [ "${app}/bin/audiobookshelf" "--port" "80" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "80/tcp" = { };
    };
    # Matches the deployment securityContext (runAsUser/fsGroup 1000) and
    # the ownership of the audiobookshelf-data files.
    User = "1000";
  };
}
