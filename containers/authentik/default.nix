# Nix-built Authentik identity provider
# Uses nixpkgs authentik package (ak entrypoint wrapping Go server + Python worker)
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  # Wrapper entrypoint that sets up /blueprints symlinks before running ak.
  # buildLayeredImage's extraCommands can't access store paths from contents (they're
  # in separate layers), so we create the symlinks at container start instead.
  entrypoint = pkgs.writeShellScript "authentik-entrypoint" ''
    # Link built-in blueprint dirs from the Nix store into /blueprints
    for item in /nix/store/*authentik-django*/blueprints/*/; do
      name=$(basename "$item")
      [ ! -e "/blueprints/$name" ] && ln -s "$item" "/blueprints/$name" 2>/dev/null || true
    done
    exec ${pkgs.authentik}/bin/ak "$@"
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/authentik";
  tag = "latest";

  contents = [
    pkgs.authentik
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.tzdata
  ];

  # Create /blueprints as world-writable so user 65534 can create symlinks at runtime.
  # The nixpkgs authentik-django package hardcodes blueprints_dir to its Nix store path,
  # making custom blueprints mounted at /blueprints/custom invisible. The entrypoint
  # wrapper populates this directory with symlinks to built-in blueprints on each start.
  extraCommands = ''
    mkdir -p blueprints
    chmod 777 blueprints
  '';

  config = {
    Entrypoint = [ "${entrypoint}" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "AUTHENTIK_BLUEPRINTS_DIR=/blueprints"
    ];
    ExposedPorts = {
      "9000/tcp" = { };
      "9443/tcp" = { };
    };
    User = "65534";
  };
}
