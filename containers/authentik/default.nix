# Nix-built Authentik identity provider (from source)
#
# Assembles four component derivations into a container image:
#   1. webui          — Lit frontend (esbuild + rollup)
#   2. authentik-django — Python backend + lifecycle scripts
#   3. authentik-server — Go HTTP server binary
#   4. ak wrapper      — sets PATH/VIRTUAL_ENV, delegates to lifecycle/ak
#
# Built with dockerTools.buildLayeredImage for efficient layer caching.
{ pkgs ? import <nixpkgs> { } }:

let
  sources = import ./sources.nix { inherit pkgs; };
  # Duplicated from sources.nix so build-container-nix.yaml can grep it
  version = "2026.2.0";
  webui = import ./webui.nix { inherit pkgs sources; };
  authentik-django = import ./authentik-django.nix { inherit pkgs sources webui; };
  authentik-server = import ./authentik-server.nix { inherit pkgs sources authentik-django webui; };

  # Wrapper that provides bin/ak with the correct runtime environment.
  # lifecycle/ak dispatches: "server" → Go binary, "worker"/"migrate"/etc → Python.
  ak = pkgs.writeShellScriptBin "ak" ''
    export PYTHONDONTWRITEBYTECODE=1
    export PATH="${authentik-server}/bin:${authentik-django}/bin:$PATH"
    export VIRTUAL_ENV="${authentik-django}"
    cd "${authentik-django}"
    exec "${authentik-django}/lifecycle/ak" "$@"
  '';

  # Container entrypoint: symlink built-in blueprints then run ak.
  # buildLayeredImage's extraCommands can't access store paths from contents
  # (they're in separate layers), so we create the symlinks at container start.
  entrypoint = pkgs.writeShellScript "authentik-entrypoint" ''
    for item in ${authentik-django}/blueprints/*/; do
      name=$(basename "$item")
      [ ! -e "/blueprints/$name" ] && ln -s "$item" "/blueprints/$name" 2>/dev/null || true
    done
    exec ${ak}/bin/ak "$@"
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/authentik";
  tag = "latest";

  contents = [
    ak
    authentik-django
    authentik-server
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.tzdata
  ];

  # Create /blueprints as world-writable so user 65534 can create symlinks at runtime.
  # authentik-django hardcodes blueprints_dir to $out/blueprints; the AUTHENTIK_BLUEPRINTS_DIR
  # env var overrides it to /blueprints, where custom blueprints are mounted by k8s ConfigMap.
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
