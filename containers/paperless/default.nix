# Nix-built Paperless-ngx for ringtail (amd64).
#
# Replaces the from-source Dockerfile build (s6-overlay) with nixpkgs'
# paperless-ngx, which already bundles the full OCR/imaging closure
# (tesseract, ghostscript, imagemagick, qpdf, poppler, jbig2enc) and the
# NLTK data via wrappers — so the image stays lean.
#
# Unlike the upstream s6 image, this image does NOT run all processes
# itself. Paperless is multi-process; on ringtail it runs as four
# containers sharing this one image, each with a different command:
#   web      -> paperless-web        (granian, the wrapper below)
#   worker   -> celery --app paperless worker
#   beat     -> celery --app paperless beat
#   consumer -> paperless-ngx document_consumer
# plus a redis/valkey sidecar. The PYTHONPATH/granian invocation mirrors
# the nixpkgs paperless NixOS module's paperless-web service exactly.
#
# Self-pins nixos-unstable: stable nixpkgs lags at 2.19.6, while unstable
# carries 2.20.15 — a same-minor forward patch bump from the previous
# Dockerfile build (v2.20.13). The version assertion makes nix-build fail
# if a pin bump changes the version, forcing an explicit acknowledgment
# here and in service-versions.yaml (enforced by container-version-check).
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/331800de5053fcebacf6813adb5db9c9dca22a0c.tar.gz";
    sha256 = "1p54fm6dkbq62kpi55cr4wyx7b1nsajpsnjgs64cmp073fwi15f7";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "2.20.15";

  app = pkgs.paperless-ngx;

  # Mirror the NixOS module's paperless-web service: granian serving the
  # ASGI app with the package's propagated deps + src on PYTHONPATH.
  pythonPath =
    "${app.python.pkgs.makePythonPath app.propagatedBuildInputs}:${app}/lib/paperless-ngx/src";

  paperless-web = pkgs.writeShellScriptBin "paperless-web" ''
    export PYTHONPATH="${pythonPath}"
    export PAPERLESS_NLTK_DIR="${app.nltkDataDir}"
    exec ${app.python.pkgs.granian}/bin/granian \
      --interface asginl --ws \
      --host 0.0.0.0 --port 8000 \
      "paperless.asgi:application"
  '';
in

assert app.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/paperless";

  contents = [
    app
    paperless-web
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.gnutar
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    # Default command is the web server; worker/beat/consumer containers
    # override `command` in their k8s manifests.
    Cmd = [ "${paperless-web}/bin/paperless-web" ];
    Env = [
      "PAPERLESS_NLTK_DIR=${app.nltkDataDir}"
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "PYTHONUNBUFFERED=1"
      "PNGX_CONTAINERIZED=1"
    ];
    ExposedPorts = {
      "8000/tcp" = { };
    };
    # Run as uid 1000 per the PSA non-root decision (docs/reference/operations/security.md).
    User = "1000";
  };
}
