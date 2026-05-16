# Nix-built shower app container — Adelaide / Heidi / Addie baby shower.
#
# The app is published as a wheel to the Forgejo PyPI index at
# https://forge.ops.eblu.me/api/packages/eblume/pypi/ (tailnet-only — the
# public forge.eblu.me /api/packages/* surface is blocked at the Fly edge).
# We can't point pip at Forgejo's simple index even from the tailnet,
# because Forgejo's index returns absolute file URLs hardcoded to its
# public ROOT_URL (forge.eblu.me), which then 403s. So both the wheel and
# the sdist are pulled by direct `fetchurl` against forge.ops.eblu.me, and
# the wheel is then handed to `pip install` as a local path; transitive
# deps come from pypi.ops.eblu.me. Build runs on the nix-container-builder
# runner (ringtail, amd64) so the image is native.
#
# Going through pip-install-target rather than nixpkgs Python packages
# sidesteps two issues we hit going through `python.pkgs.buildPythonPackage`:
#   1. python314Packages.django still aliases to Django 4.2 LTS, which
#      doesn't support Python 3.14 at all.
#   2. django-axes pulls selenium + browser fonts into its check phase
#      and the nix sandbox can't provide those.
#
# To bump the version:
#   1. Update `version` below.
#   2. Set `outputHash` to `pkgs.lib.fakeHash`, run the build, copy the
#      real hash out of the error, and commit it.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.1.3";

  python = pkgs.python314;

  # The repo's top-level static/ directory (vendored Sortable + cropper
  # JS/CSS, prize placeholder SVG) isn't shipped in the wheel — hatchling
  # only packages config/ and shower/, leaving the repo-root static/
  # behind. Pull the sdist (which contains the full source tree) and
  # extract just the static/ subtree into the image as /app/static.
  # local_settings adds it to STATICFILES_DIRS so collectstatic at boot
  # picks it up alongside the Django admin's static files.
  #
  # Fetched from forge.ops.eblu.me (tailnet) because /api/packages/* is
  # blocked at the fly edge — see fly/nginx.conf forge.eblu.me block.
  # Hash is the upstream sha256 from forge PyPI's simple index.
  showerSdist = pkgs.fetchurl {
    name = "adelaide_baby_shower_app-${version}.tar.gz";
    url = "https://forge.ops.eblu.me/api/packages/eblume/pypi/files/adelaide-baby-shower-app/${version}/adelaide_baby_shower_app-${version}.tar.gz";
    hash = "sha256-a3rCwEdOB+rnYXqsWDifyltpyKUgkOj0ikWB+WGQYKE=";
  };

  # Wheel pulled from forge.ops.eblu.me (tailnet) for the same reason the
  # sdist is: Forgejo's PyPI simple index would return forge.eblu.me URLs
  # that the Fly edge 403s on /api/packages/*. We hand this path to pip
  # below so it never touches the forge index at all.
  showerWheel = pkgs.fetchurl {
    name = "adelaide_baby_shower_app-${version}-py3-none-any.whl";
    url = "https://forge.ops.eblu.me/api/packages/eblume/pypi/files/adelaide-baby-shower-app/${version}/adelaide_baby_shower_app-${version}-py3-none-any.whl";
    hash = "sha256-a6j91gBigG4IzE2DVTBntnZ46Yrx9b5PgHn+Uro98Tk=";
  };

  staticAssets = pkgs.runCommand "shower-static-assets-${version}" { } ''
    ${pkgs.gnutar}/bin/tar -xzf ${showerSdist} -C $TMPDIR
    cp -r $TMPDIR/adelaide_baby_shower_app-${version}/static $out
  '';

  # Fixed-output derivation: pip-installs the app wheel + every transitive
  # dep into a single target dir. FODs get network access in exchange for
  # a pinned output hash, which means the whole dependency closure is
  # immutable across rebuilds.
  pyDepsFOD = pkgs.stdenv.mkDerivation {
    pname = "shower-python-deps-fod";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [ python pkgs.cacert pkgs.removeReferencesTo ];

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export PIP_DISABLE_PIP_VERSION_CHECK=1

      ${python}/bin/python -m venv "$TMPDIR/venv"
      "$TMPDIR/venv/bin/pip" install --upgrade pip

      # Nix store paths embed a 32-char hash prefix, which pip's wheel
      # filename parser rejects ("Invalid wheel filename"). Copy to a
      # clean filename in TMPDIR before installing.
      cp ${showerWheel} "$TMPDIR/${showerWheel.name}"

      "$TMPDIR/venv/bin/pip" install \
        --no-cache-dir \
        --index-url=https://pypi.ops.eblu.me/root/pypi/+simple/ \
        "$TMPDIR/${showerWheel.name}" \
        gunicorn

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/python3.14 $out/bin
      cp -r "$TMPDIR/venv/lib/python3.14/site-packages" $out/lib/python3.14/site-packages

      for script in "$TMPDIR/venv/bin/"*; do
        [ -f "$script" ] || continue
        name=$(basename "$script")
        case "$name" in
          python*|pip*|activate*) continue ;;
        esac
        cp "$script" "$out/bin/$name"
        chmod +x "$out/bin/$name"
      done

      # --- Strip Nix store references (FOD outputs must be self-contained) ---
      # The wrapper derivation below restores them via autoPatchelfHook + a
      # python wrapper that points pyc-less imports at the on-image python.

      # Strip bytecode entirely — pyc files embed compile-time paths.
      find $out -type f -name '*.pyc' -delete
      find $out -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true

      # Dynamically discover all nix store references and strip them. We
      # don't have a static list because pip pulls in stdenv via Python's
      # build env (gcc-lib, libstdc++, etc.) and the closure is opaque.
      { find $out -type f -print0 \
          | xargs -0 grep -aohE '/nix/store/[a-z0-9]{32}-[^/"[:space:]]+' 2>/dev/null \
          || true; } | sort -u > $TMPDIR/store-refs.txt
      echo "Found $(wc -l < $TMPDIR/store-refs.txt) unique store path references to strip"

      refs_args=""
      while IFS= read -r ref; do
        refs_args="$refs_args -t $ref"
      done < $TMPDIR/store-refs.txt

      if [ -n "$refs_args" ]; then
        find $out -type f -exec remove-references-to $refs_args {} + 2>/dev/null || true
      fi

      remaining=$({ find $out -type f -print0 | xargs -0 grep -cl '/nix/store/' 2>/dev/null || true; } | wc -l)
      echo "Files with remaining store references: $remaining"

      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    # Pinned dep closure — reproducible until version bumps. To recompute,
    # set to pkgs.lib.fakeHash and read the failure.
    outputHash = "sha256-1xx2qWAIwherklHIPXo6IOKkKHML1KUrUx6pbkMxffc=";

    dontFixup = true;
  };

  # Non-FOD wrapper: re-applies RPATHs to pre-built .so files (pillow,
  # scipy) so they find libstdc++ / libz / etc. at runtime. autoPatchelfHook
  # discovers needed libraries from buildInputs.
  pyDeps = pkgs.stdenv.mkDerivation {
    pname = "shower-python-deps";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    buildInputs = with pkgs; [
      python
      stdenv.cc.cc.lib   # libstdc++, libgcc_s
      zlib
      libjpeg
      libwebp
      libtiff
      openjpeg
      lcms2
      freetype
    ];

    installPhase = ''
      cp -r ${pyDepsFOD} $out
      chmod -R u+w $out
    '';
  };

  sitePackages = "${pyDeps}/lib/python3.14/site-packages";

  # Settings shim — config/settings.py's `BASE_DIR = parent.parent` would
  # otherwise resolve to site-packages, scattering db.sqlite3 / media /
  # staticfiles into the venv. Pin them to /app/{data,media,data/staticfiles}.
  localSettings = pkgs.writeText "local_settings.py" ''
    from pathlib import Path

    from config.settings import *  # noqa: F401,F403

    DATABASES["default"]["NAME"] = "/app/data/db.sqlite3"
    MEDIA_ROOT = "/app/media"
    STATIC_ROOT = "/app/data/staticfiles"
    # /app/static comes from the repo-root static/ subtree of the sdist
    # (see default.nix staticAssets). Added because the wheel doesn't
    # ship vendored Sortable/cropper assets.
    STATICFILES_DIRS = [Path("/app/static")]
  '';

  # PYTHONPATH, DJANGO_SETTINGS_MODULE, PATH, and HOME live in the image's
  # `Env` block below — that way `kubectl exec deploy/shower -- python -m
  # django <subcommand>` Just Works without an inline `env` ceremony.
  # The entrypoint just changes directory and runs the boot sequence.
  entrypoint = pkgs.writeShellScript "shower-entrypoint" ''
    set -eu

    cd /app

    mkdir -p /app/data /app/media

    echo "shower: running migrations"
    python -m django migrate --noinput

    echo "shower: collecting static files"
    python -m django collectstatic --noinput --clear

    echo "shower: starting gunicorn"
    exec gunicorn \
      --bind 0.0.0.0:8000 \
      --workers 2 \
      --forwarded-allow-ips='*' \
      config.wsgi:application
  '';
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/shower";
  contents = [
    python
    pyDeps
    pkgs.cacert
    pkgs.tzdata
    pkgs.bashInteractive
    pkgs.coreutils
  ];

  extraCommands = ''
    mkdir -p app/data app/media tmp
    chmod 1777 tmp
    cp ${localSettings} app/local_settings.py
    cp -r ${staticAssets} app/static
    chmod -R u+w app/static
  '';

  fakeRootCommands = ''
    chown -R 1000:1000 app
  '';
  enableFakechroot = true;

  config = {
    Entrypoint = [ "${entrypoint}" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "TZ=America/Los_Angeles"
      "TMPDIR=/tmp"
      "LANG=C.UTF-8"
      "LC_ALL=C.UTF-8"
      "PYTHONDONTWRITEBYTECODE=1"
      "HOME=/app/data"
      "PATH=${pyDeps}/bin:${python}/bin:/bin"
      # /app first so local_settings.py is importable; sitePackages second so
      # django, gunicorn, etc. resolve. Inherited by entrypoint + any
      # `kubectl exec` so manual django subcommands work without ceremony.
      "PYTHONPATH=/app:${sitePackages}"
      "DJANGO_SETTINGS_MODULE=local_settings"
    ];
    ExposedPorts = {
      "8000/tcp" = { };
    };
    User = "1000";
    WorkingDir = "/app";
  };
}
