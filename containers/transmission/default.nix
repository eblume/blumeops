# Nix-built Transmission for ringtail (amd64), phase 1 of [[retire-minikube]].
#
# Replaces the Alpine-edge build. nixpkgs transmission_4 is 4.1.1 — the
# same upstream as the alpine 4.1.1-r1 package. The PUID/PGID + su-exec
# dance from start.sh is replaced by a fixed uid-1000 user (matching the
# ownership of the existing NFS download dirs); the ringtail deployment
# sets runAsUser/fsGroup 1000 so the /config emptyDir is writable.
#
# This image is also the kiwix torrent-sync sidecar: it needs bash, curl,
# transmission-remote, and coreutils/awk/xargs for sync-zim-torrents.sh.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "4.1.1";
  app = pkgs.transmission_4;

  # start.sh equivalent: default settings.json on first boot, then exec
  # the daemon. /config is an emptyDir — settings are ephemeral by design.
  #
  # RPC auth turns on when TRANSMISSION_RPC_USERNAME/_PASSWORD are both set
  # (wired from external-secrets in the deployment). The password goes into
  # settings.json rather than daemon flags so it never shows in the process
  # cmdline; transmission rewrites it as a salted hash on startup. Missing
  # credentials fall back to open RPC so the kiwix torrent-sync sidecar
  # (which runs this image without them) keeps working.
  transmission-run = pkgs.writeShellScriptBin "transmission-run" ''
    set -e
    mkdir -p /config /downloads/complete /downloads/incomplete
    CONFIG_FILE=/config/settings.json
    AUTH_ENABLED=false
    if [ -n "''${TRANSMISSION_RPC_USERNAME:-}" ] && [ -n "''${TRANSMISSION_RPC_PASSWORD:-}" ]; then
      AUTH_ENABLED=true
    fi
    if [ ! -f "$CONFIG_FILE" ]; then
      echo "Creating default configuration (rpc auth: $AUTH_ENABLED)..."
      cat > "$CONFIG_FILE" << EOF
    {
        "download-dir": "/downloads/complete",
        "incomplete-dir": "/downloads/incomplete",
        "incomplete-dir-enabled": true,
        "rpc-enabled": true,
        "rpc-bind-address": "0.0.0.0",
        "rpc-port": 9091,
        "rpc-authentication-required": $AUTH_ENABLED,
        "rpc-username": "''${TRANSMISSION_RPC_USERNAME:-}",
        "rpc-password": "''${TRANSMISSION_RPC_PASSWORD:-}",
        "rpc-whitelist-enabled": false,
        "rpc-host-whitelist-enabled": false,
        "peer-port": 51413,
        "watch-dir-enabled": false,
        "umask": 2
    }
    EOF
    fi
    echo "Starting transmission-daemon..."
    exec transmission-daemon --foreground --config-dir /config --log-level=info
  '';
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/transmission";

  contents = [
    app
    transmission-run
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.gawk
    pkgs.findutils
    pkgs.gnugrep
    pkgs.curl
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Cmd = [ "${transmission-run}/bin/transmission-run" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
    ];
    ExposedPorts = {
      "9091/tcp" = { };
      "51413/tcp" = { };
      "51413/udp" = { };
    };
    User = "1000";
  };
}
