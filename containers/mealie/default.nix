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
# Self-pins nixos-unstable: stable nixpkgs lags well behind. Bumped
# 2026-07-22 from 3.16.0 -> 3.20.1 (the filed task targeted v3.17.0, but
# unstable has since moved past it — bump-with-review to what unstable
# currently carries, navidrome precedent). Reuses the same pinned rev+hash
# as containers/navidrome/default.nix (no new hash fetch needed).
#
# Breaking-change review v3.17.0 - v3.20.1: no DB/schema breaking changes
# in any of these releases — mealie continues to auto-migrate the SQLite DB
# forward on startup via init_db, unaffected. Notable items along the way:
# a query-filter-API data-exposure fix (GHSA-8m57-7cv5-rjp8, v3.19.0),
# stored-XSS hardening for recipe content (v3.18.0/v3.20.0), an OIDC
# missing-claims log downgraded from ERROR to DEBUG, a Home Assistant
# i-frame cookie-settings refactor, and in-app AI provider config replacing
# OPENAI_API_KEY-style env vars (v3.19.0 — existing env vars are
# auto-imported once on upgrade; moot here since this deploy sets none).
# Source PVC retained for rollback. The version assertion makes nix-build
# fail if a pin bump changes the version.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/241313f4e8e508cb9b13278c2b0fa25b9ca27163.tar.gz";
    sha256 = "09d83cyl9dlfkkbspkgkk7bfydj3mvw6r1x98kvc2v8wl2xd8ldy";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "3.20.1";

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
