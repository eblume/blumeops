# Nix-built Authentik identity provider (from source)
#
# Assembles four component derivations into a container image:
#   1. webui          — Lit frontend (esbuild + rollup)
#   2. authentik-django — Python backend + lifecycle scripts
#   3. authentik-server — Go HTTP server binary
#   4. ak wrapper      — sets PATH/VIRTUAL_ENV, delegates to lifecycle/ak
#
# Built with dockerTools.buildLayeredImage for efficient layer caching.
{ pkgs ? import <nixpkgs> { }, buildHash ? "nix" }:

let
  sources = import ./sources.nix { inherit pkgs; };
  # Duplicated from sources.nix so build-container.yaml can grep it
  version = "2026.2.6";
  webui = import ./webui.nix { inherit pkgs sources buildHash; };
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

in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/authentik";
  # authentik-django is deliberately NOT in contents: contents get linked into
  # the image root, which put a /blueprints tree of symlinks into /nix/store
  # there. authentik's retrieve_file resolve()s each blueprint path and rejects
  # anything outside blueprints_dir ("Invalid blueprint path"), so every
  # built-in blueprint failed. It still ships in the image as a dependency of
  # ak, which references it by store path.
  contents = [
    ak
    authentik-server
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.tzdata
  ];

  # /blueprints holds the built-in blueprints as real files (AUTHENTIK_BLUEPRINTS_DIR
  # points here; custom/ is the k8s ConfigMap mount). Copy dereferenced (-L) and
  # fail the build if any symlink survives: a symlink into /nix/store resolves
  # outside blueprints_dir and authentik silently refuses to apply it.
  extraCommands = ''
    mkdir -p blueprints tmp
    cp -rL ${authentik-django}/blueprints/. blueprints/
    chmod -R u+w blueprints
    if [ -n "$(find blueprints -type l)" ]; then
      echo "error: symlinks under /blueprints; authentik will reject them:" >&2
      find blueprints -type l >&2
      exit 1
    fi
    chmod 777 blueprints tmp
  '';

  config = {
    Entrypoint = [ "${ak}/bin/ak" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "TMPDIR=/tmp"
      "AUTHENTIK_BLUEPRINTS_DIR=/blueprints"
      # Must match the web build so authentik_full_version() resolves the
      # entry bundle filenames.
      "GIT_BUILD_HASH=${buildHash}"
    ];
    ExposedPorts = {
      "9000/tcp" = { };
      "9443/tcp" = { };
    };
    User = "65534";
  };
}
