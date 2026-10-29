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
# Self-pins nixos-unstable: stable nixpkgs lags well behind. Bumped to
# 3.22.0 (nixpkgs 559dfb35, first unstable rev carrying exactly 3.22.0).
# v3.22.0 needs OIDC_REQUIRES_EMAIL_VERIFICATION=false on the deployment
# (Authentik does not emit email_verified). The v3.29.0 train is separate.
# The version assertion makes nix-build fail if a pin bump changes the
# version.
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/559dfb35549e3386bbf041e2d3a084ce059f6586.tar.gz";
    sha256 = "164g8pp61439hkjsjizh51nnc1dbq9lnqnkbahp3m0g2gqvgpvdl";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "3.22.0";

  app = pkgs.mealie;

  # ingredient-parser-nlp calls nltk.download("averaged_perceptron_tagger_eng")
  # at import unless nltk.data.find() already locates the tagger. Bake it
  # into the image (NLTK_DATA below) so startup neither reaches out to
  # GitHub nor needs a writable $HOME - as uid 1000 the fallback target
  # was /nltk_data, which crash-looped the first non-root rollout (#888).
  nltk-tagger = pkgs.runCommand "nltk-averaged-perceptron-tagger-eng" {
    src = pkgs.fetchurl {
      url = "https://forge.ops.eblu.me/mirrors/nltk_data/raw/branch/gh-pages/packages/taggers/averaged_perceptron_tagger_eng.zip";
      sha256 = "02wgf70r4yl8x61h62h3msdygd2pndblgm27cmywcda3c8qga9b0";
    };
    nativeBuildInputs = [ pkgs.unzip ];
  } ''
    mkdir -p $out/usr/share/nltk_data/taggers
    unzip -q $src -d $out/usr/share/nltk_data/taggers
    test -f $out/usr/share/nltk_data/taggers/averaged_perceptron_tagger_eng/averaged_perceptron_tagger_eng.weights.json
  '';

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
    nltk-tagger
  ];

  # gunicorn's worker heartbeat needs a usable temp dir and the image
  # otherwise has none; as root it appeared on the fly, as uid 1000 it
  # cannot (#889). Same shape as teslamate.
  extraCommands = ''
    mkdir -p tmp
    chmod 1777 tmp
  '';

  config = {
    Cmd = [ "${mealie-run}/bin/mealie-run" ];
    Env = [
      "DATA_DIR=/app/data"
      "NLTK_DATA=/usr/share/nltk_data"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PYTHONUNBUFFERED=1"
      "PRODUCTION=true"
    ];
    ExposedPorts = {
      "9000/tcp" = { };
    };
    # Run as uid 1000 per the PSA non-root decision (docs/reference/operations/security.md).
    User = "1000";
  };
}
