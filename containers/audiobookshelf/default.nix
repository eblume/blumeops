# Nix-built Audiobookshelf for ringtail (amd64) — serves the audiobooks that
# live in the sifaka music share (/volume1/music/Audiobooks, eblume/blumeops#1120).
#
# Self-pins nixos-unstable (navidrome precedent): the fleet pin (navidrome /
# mealie / miniflux) predates the 2.38.0 package. The pin is the nixpkgs commit
# that bumped audiobookshelf to 2.38.0 rather than the branch head: the head
# adds nixpkgs fetchpatch FODs that fail the eval-based FOD check. The version
# assertion makes nix-build fail if a pin bump changes the version unexpectedly.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/163531fba99642fd74dcc6b08789f97b15709fe5.tar.gz";
    sha256 = "0nfjr7451hsj52dyy1gsqykjg7zrql502j2m791bjwd7ccl3jlfw";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "2.38.0";
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
    # indri borgmatic k8s-file-dump helper). The base nix image ships no
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
