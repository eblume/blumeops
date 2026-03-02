# Authentik Python/Django backend
#
# Assembles the final package from:
#   1. python-deps FOD (venv with stripped store references)
#   2. opencontainers git dependency (fetched via Nix)
#   3. Workspace packages (ak-guardian, django-channels-postgres, etc.)
#   4. Authentik application source
#   5. Lifecycle scripts, blueprints, manage.py
#
# autoPatchelfHook restores RPATHs that were stripped in the FOD.
#
# Optional input: webui derivation. When provided, resolves @webui@ store
# path placeholders in Python source. When null (default), leaves placeholders
# for isolated testing.
#
# Output:
#   $out/bin/python3.14                    venv python (symlink to nix python314)
#   $out/lib/python3.14/site-packages/     all Python packages
#   $out/lifecycle/                         lifecycle scripts (symlink)
#   $out/blueprints/                        YAML blueprints
#   $out/manage.py                          Django management script
{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
, webui ? null
}:

let
  python-deps = import ./python-deps.nix { inherit pkgs sources; };

  # opencontainers is a git dependency not on PyPI — fetch separately
  opencontainers-src = pkgs.fetchFromGitHub {
    owner = "vsoch";
    repo = "oci-python";
    rev = "ceb4fcc090851717a3069d78e85ceb1e86c2740c";
    hash = "sha256-Q6SJed0K6eIrqQ9mNAD4RGx+YCJvnI5E+0KGp5fBtTU=";
  };

  # When webui is provided, resolve paths directly; otherwise use placeholder
  webuiPath = if webui != null then "${webui}" else "@webui@";

  sp = "$out/lib/python3.14/site-packages";
in

pkgs.stdenv.mkDerivation {
  pname = "authentik-django";
  version = sources.version;
  inherit (sources) meta;

  src = sources.src;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook  # restores RPATHs stripped in the FOD
  ];

  # Libraries that autoPatchelfHook resolves NEEDED entries against
  buildInputs = with pkgs; [
    python314
    stdenv.cc.cc.lib  # libstdc++, libgcc_s
    libxml2
    libxslt
    xmlsec
    openssl
    libpq
    krb5.lib
    libtool.lib
    libffi
    zlib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # --- Copy venv from FOD ---
    cp -r ${python-deps} $out
    chmod -R +w $out

    # Restore python path in pyvenv.cfg (was replaced with @python@ in FOD)
    sed -i "s|@python@|${pkgs.python314}|g" $out/pyvenv.cfg

    # Recreate bin/ (was removed in FOD to strip python store refs)
    mkdir -p $out/bin
    ln -s ${pkgs.python314}/bin/python3.14 $out/bin/python3.14
    ln -s python3.14 $out/bin/python3
    ln -s python3.14 $out/bin/python

    # Recreate entry point scripts that were in the venv's bin/
    # (gunicorn, etc. — use python from this venv)
    for ep in gunicorn uvicorn dramatiq dumb-init; do
      if [ -e ${sp}/$ep ] || $out/bin/python3.14 -c "import $ep" 2>/dev/null; then
        cat > $out/bin/$ep << SCRIPT
    #!$out/bin/python3.14
    import sys
    from importlib.metadata import entry_points
    eps = entry_points(group='console_scripts', name='$ep')
    if eps:
        sys.exit(next(iter(eps)).load()())
    SCRIPT
        chmod +x $out/bin/$ep
      fi
    done 2>/dev/null || true

    # --- opencontainers (git dependency, pure Python) ---
    cp -r ${opencontainers-src}/opencontainers ${sp}/opencontainers

    # --- Workspace packages (pure Python — direct copy) ---
    # ak-guardian: hatch config maps to "guardian" package
    cp -r packages/ak-guardian/guardian         ${sp}/guardian
    cp -r packages/django-channels-postgres/django_channels_postgres ${sp}/
    cp -r packages/django-dramatiq-postgres/django_dramatiq_postgres ${sp}/
    cp -r packages/django-postgres-cache/django_postgres_cache       ${sp}/

    # --- Authentik application + lifecycle ---
    cp -r authentik ${sp}/authentik
    cp -r lifecycle ${sp}/lifecycle
    chmod +x ${sp}/lifecycle/ak

    # --- Patches for Nix store paths ---

    # BASE_DIR: point to $out instead of computing from settings.py's location
    substituteInPlace ${sp}/authentik/root/settings.py \
      --replace-fail \
        'BASE_DIR = Path(__file__).absolute().parent.parent.parent' \
        "BASE_DIR = Path(\"$out\")"

    # blueprints_dir: point to $out/blueprints
    substituteInPlace ${sp}/authentik/lib/default.yml \
      --replace-fail 'blueprints_dir: /blueprints' \
                     "blueprints_dir: $out/blueprints"

    # Web asset paths: placeholder @webui@ for Go server card to resolve
    substituteInPlace ${sp}/authentik/stages/email/utils.py \
      --replace-fail 'Path("web/icons/icon_left_brand.png")' \
                     'Path("${webuiPath}/icons/icon_left_brand.png")' \
      --replace-fail 'Path("web/dist/assets/icons/icon_left_brand.png")' \
                     'Path("${webuiPath}/dist/assets/icons/icon_left_brand.png")'

    # Lifecycle bash script: use Nix store bash (no /usr/bin/env in containers)
    substituteInPlace ${sp}/lifecycle/ak \
      --replace-fail '#!/usr/bin/env -S bash' '#!${pkgs.bash}/bin/bash'

    # --- Top-level structure ---
    ln -s ${sp}/lifecycle $out/lifecycle
    ln -s ${sp}/authentik $out/authentik
    cp -r blueprints $out/blueprints
    cp manage.py $out/manage.py

    runHook postInstall
  '';

  # autoPatchelfHook runs in fixupPhase — don't disable it
  dontPatchShebangs = true;
}
