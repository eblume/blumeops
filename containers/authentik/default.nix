# Nix-built Authentik identity provider
# Uses nixpkgs authentik package (ak entrypoint wrapping Go server + Python worker)
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

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

  # Create /blueprints with symlinks to built-in blueprint dirs from the Nix store.
  # The nixpkgs authentik-django package hardcodes blueprints_dir to its Nix store path,
  # making custom blueprints mounted at /blueprints/custom invisible. This creates a
  # stable /blueprints root that includes both built-in and custom blueprint directories.
  extraCommands = ''
    mkdir -p blueprints
    for item in nix/store/*authentik-django*/blueprints/*; do
      name=$(basename "$item")
      ln -s "/$item" "blueprints/$name"
    done
  '';

  config = {
    Entrypoint = [ "${pkgs.authentik}/bin/ak" ];
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
