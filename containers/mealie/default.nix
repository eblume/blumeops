# Nix-built Mealie for ringtail (amd64).
#
# Replaces the from-source Dockerfile build (Node frontend + Python venv)
# with nixpkgs' mealie, which ships a single `mealie` gunicorn entrypoint
# serving the prebuilt frontend + backend — so this is a clean single-
# process wrap (unlike paperless, which is multi-process).
#
# Mealie stores its DB as SQLite under DATA_DIR (the mealie-data PVC at
# /app/data); there is no postgres. The run wrapper mirrors the nixpkgs
# mealie NixOS module: run `libexec/init_db` (Alembic migrations) first,
# then exec gunicorn.
#
# Self-pins nixos-unstable: stable nixpkgs lags at 3.9.2, unstable carries
# 3.16.0. This is a forward 4-minor bump from the v3.12.0 Dockerfile build
# (the deferred upgrade) — mealie auto-migrates the SQLite DB forward on
# startup via init_db; the source PVC is retained for rollback. The version
# assertion makes nix-build fail if a pin bump changes the version.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/331800de5053fcebacf6813adb5db9c9dca22a0c.tar.gz";
    sha256 = "1p54fm6dkbq62kpi55cr4wyx7b1nsajpsnjgs64cmp073fwi15f7";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "3.16.0";

  app = pkgs.mealie;

  # Mirror the NixOS module's mealie service: init_db (Alembic) then
  # gunicorn bound to the app port. DATA_DIR/env come from the image +
  # k8s manifest.
  mealie-run = pkgs.writeShellScriptBin "mealie-run" ''
    set -e
    ${app}/libexec/init_db
    exec ${pkgs.lib.getExe app} -b 0.0.0.0:9000
  '';
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/mealie";

  contents = [
    app
    mealie-run
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.tzdata
    # python3 (stdlib sqlite3) for the borgmatic k8s-sqlite-dump helper,
    # which runs `python3 -c "...sqlite3...backup..."` inside the pod.
    # Same nixpkgs python mealie is built against, so ~no added closure.
    pkgs.python3
  ];

  config = {
    Cmd = [ "${mealie-run}/bin/mealie-run" ];
    Env = [
      "DATA_DIR=/app/data"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PYTHONUNBUFFERED=1"
      "PRODUCTION=true"
    ];
    ExposedPorts = {
      "9000/tcp" = { };
    };
  };
}
