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
# Compiled .so files also carry DWARF debug info embedding uv's random
# per-build sdist path, so we strip it (strip --strip-debug) to keep the
# FOD output — and its outputHash — deterministic.
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
    binutils              # strip for .so debug info
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

    # Strip DWARF from compiled extensions: their debug info embeds
    # uv's random per-build sdist path (nondeterministic FOD output).
    find $out -type f -name '*.so*' -exec strip --strip-debug {} +

    # Fail loudly if a uv sdist build path leaked into the output.
    if grep -Rqas 'sdists-v' $out; then
      echo "ERROR: uv sdist build path leaked into FOD output"
      exit 1
    fi

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

    # Verify — report any remaining references (nix base32 store-path hash, which
    # has no 'e', so remove-references-to's eeeee... padding is not counted)
    remaining=$({ find $out -type f -print0 | xargs -0 grep -lcE '/nix/store/[0-9a-df-np-sv-z]{32}-' 2>/dev/null || true; } | wc -l)
    echo "Files with remaining store references: $remaining"
    if [ "$remaining" -gt 0 ]; then
      echo "WARNING: Files still containing store references:"
      { find $out -type f -print0 | xargs -0 grep -lE '/nix/store/[0-9a-df-np-sv-z]{32}-' 2>/dev/null || true; }
    fi

    # Recompute every dist-info RECORD last. Their sha256 lines were written by
    # uv before the strip and reference rewrites above, so for sdist-built
    # extensions they hash the *pre-strip* .so, whose debug info embeds uv's
    # random sdist path: the stripped files are identical across builds but
    # RECORD was not, so the FOD hash drifted every fresh build (I6tw / ZKob /
    # mhVOD from one input set). Rewriting RECORD from the shipped bytes makes
    # it both deterministic and accurate.
    #
    # Two wheels (django-tenants, pyrad) both ship a stray top-level docs/ tree,
    # so docs/Makefile is whichever uv's parallel install wrote last: a second
    # source of drift. It is Sphinx source, never imported; drop it. The script
    # then fails the build if any shipped file is still claimed by two packages.
    rm -rf $out/lib/python3.14/site-packages/docs
    python3 - "$out" <<'PY'
import base64, collections, csv, hashlib, io, pathlib, sys
root = pathlib.Path(sys.argv[1])
owners = collections.defaultdict(list)
for record in sorted(root.rglob("*.dist-info/RECORD")):
    if record.is_symlink():
        continue
    for row in csv.reader(io.StringIO(record.read_text())):
        if row and (record.parent.parent / row[0]).is_file():
            owners[(record.parent.parent, row[0])].append(record.parent.name)
clashes = {k: v for k, v in owners.items() if len(v) > 1}
if clashes:
    for (site, path), pkgs in sorted(clashes.items()):
        print(f"ERROR: {path} is installed by several packages: {pkgs}", file=sys.stderr)
    sys.exit("file collisions make the FOD output depend on uv's install order")
for record in sorted(root.rglob("*.dist-info/RECORD")):
    if record.is_symlink():
        continue
    site = record.parent.parent
    rows = list(csv.reader(io.StringIO(record.read_text())))
    out = io.StringIO()
    w = csv.writer(out, lineterminator="\n")
    for row in rows:
        if len(row) >= 3 and row[1]:
            p = site / row[0]
            if p.is_file() and not p.is_symlink():
                data = p.read_bytes()
                digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
                row = [row[0], "sha256=" + digest, str(len(data))]
        w.writerow(row)
    record.write_text(out.getvalue())
PY

    runHook postInstall
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-U0LzkP/9XJXhUhOdpf0C9z4T+cQrB8L/WeeTrMcImjA=";

  dontFixup = true;
}
