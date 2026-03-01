# Fixed-output derivation (FOD): download and install all external Python
# dependencies into a venv using uv sync.
#
# FODs get network access because the output hash is declared upfront.
# However, FODs must not reference other Nix store paths in their output.
# Compiled .so files (from sdist builds) contain RPATHs to system libraries
# (libxml2, krb5, etc.) which are Nix store paths. We strip these references
# here; authentik-django.nix restores them via autoPatchelfHook.
#
# The venv's bin/ and pyvenv.cfg also reference the python store path, so we
# replace them with placeholders that the main derivation restores.
#
# When uv.lock changes, reset outputHash to pkgs.lib.fakeHash, build to
# get the correct hash from the error message, then update.
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

pkgs.stdenv.mkDerivation {
  pname = "authentik-python-deps";
  version = sources.version;

  src = sources.src;

  nativeBuildInputs = with pkgs; [
    python314
    uv
    git     # opencontainers is a git dependency in uv.lock
    cacert  # HTTPS verification for PyPI + GitHub
    pkg-config
    removeReferencesTo
    # Build tools on PATH for sdist compilation
    postgresql.pg_config  # pg_config for psycopg-c
    krb5                  # krb5-config for gssapi
  ];

  # System libraries for packages that must build from sdist:
  #   lxml, xmlsec    — pyproject.toml [tool.uv] no-binary-package
  #   psycopg-c       — sdist only on PyPI
  #   gssapi          — no Linux wheels on PyPI
  buildInputs = with pkgs; [
    libxml2
    libxslt
    xmlsec
    openssl
    libpq       # psycopg-c links against libpq
    libtool     # libltdl for xmlsec dynamic crypto backend loading
    libffi
    zlib
  ];

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    export UV_PYTHON=${pkgs.python314}/bin/python3.14
    export UV_LINK_MODE=copy

    # gssapi's pre-generated C code uses S4U functions declared in gssapi_ext.h
    # but doesn't include it — force-include via compiler flag
    export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE:-} -include gssapi/gssapi_ext.h"

    uv sync \
      --frozen \
      --no-install-project \
      --no-install-workspace \
      --no-dev

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mv .venv $out

    # --- Strip Nix store references (FODs must be self-contained) ---
    # autoPatchelfHook in authentik-django.nix restores correct RPATHs.

    # Replace python store path in pyvenv.cfg with placeholder
    sed -i "s|${pkgs.python314}|@python@|g" $out/pyvenv.cfg

    # Remove bin/ entirely — main derivation recreates it
    rm -rf $out/bin

    # Strip store refs from .pyc files (contain embedded paths)
    find $out -type f -name '*.pyc' -delete

    # Dynamically discover ALL remaining Nix store paths in the output.
    # This is more robust than a static list of store paths — any new
    # build/runtime dependency is automatically handled.
    # Note: || true needed because xargs returns 123 if grep returns 1
    # (no match) on any batch, and pipefail propagates that.
    { find $out -type f -print0 \
        | xargs -0 grep -aohE '/nix/store/[a-z0-9]{32}-[^/"[:space:]]+' 2>/dev/null \
        || true; } | sort -u > $TMPDIR/store-refs.txt
    echo "Found $(wc -l < $TMPDIR/store-refs.txt) unique store path references to strip"

    # Build remove-references-to args from discovered paths
    refs_args=""
    while IFS= read -r ref; do
      refs_args="$refs_args -t $ref"
    done < $TMPDIR/store-refs.txt

    # Strip all discovered references from all files
    if [ -n "$refs_args" ]; then
      find $out -type f -exec remove-references-to $refs_args {} + 2>/dev/null || true
    fi

    # Verify — report any remaining references
    remaining=$({ find $out -type f -print0 | xargs -0 grep -cl '/nix/store/' 2>/dev/null || true; } | wc -l)
    echo "Files with remaining store references: $remaining"
    if [ "$remaining" -gt 0 ]; then
      echo "WARNING: Files still containing store references:"
      { find $out -type f -print0 | xargs -0 grep -l '/nix/store/' 2>/dev/null || true; }
    fi

    runHook postInstall
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-DtpcYQyI07m7v84D/UC28Tj35R9wye6IX+1D0gMZPgY=";

  dontFixup = true;
}
