# Authentik Python/Django backend
#
# Assembles the final package from:
#   1. python-deps (venv of the locked third-party dependencies)
#   2. Workspace packages (ak-guardian, django-channels-postgres, etc.)
#   3. Authentik application source
#   4. Lifecycle scripts, blueprints, manage.py
#
# The venv's bin/python* is a compiled C shim that execs the nix python314
# with argv[0] pinned to the python-deps store path (the console scripts'
# shebangs point there too), so a plain copy would resolve sys.prefix to
# python-deps at runtime and leave the workspace packages off sys.path.
# installPhase restores plain symlinks and repoints the shebangs.
# autoPatchelfHook fixes the RPATHs of the compiled extensions built from
# sdist in python-deps.
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
    autoPatchelfHook
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

    # --- Copy venv ---
    cp -r ${python-deps} $out
    chmod -R +w $out

    # The venv's bin/python* and console-script shebangs reference the
    # python-deps store path (see header) — repoint them, or sys.prefix
    # hides the workspace packages copied below.
    rm -f $out/bin/python $out/bin/python3 $out/bin/python3.14
    ln -s ${pkgs.python314}/bin/python3.14 $out/bin/python3.14
    ln -s python3.14 $out/bin/python3
    ln -s python3.14 $out/bin/python
    for f in $out/bin/*; do
      [ -L "$f" ] || sed -i "1s|^#!${python-deps}/bin/|#!$out/bin/|" "$f"
    done

    # pyvenv.cfg and the activate scripts embed that path too; left as-is the
    # venv would stay a runtime reference of this output (double-shipped in
    # the image closure).
    sed -i "s|${python-deps}|$out|g" $out/pyvenv.cfg $out/bin/activate*

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
      --replace-fail 'Path("web/dist/assets/icons/icon_left_brand.png")' \
                     'Path("${webuiPath}/dist/assets/icons/icon_left_brand.png")'

    # Migration ordering: 0010 removes Role.group_id, but 0056 needs it
    # for data migration. Upstream bug in authentik 2026.2.0.
    # https://github.com/goauthentik/authentik/issues/19616
    substituteInPlace ${sp}/authentik/rbac/migrations/0010_remove_role_group_alter_role_name.py \
      --replace-fail \
        '("authentik_rbac", "0009_remove_initialpermissions_mode"),' \
        '("authentik_rbac", "0009_remove_initialpermissions_mode"), ("authentik_core", "0056_user_roles"),'

    # Lifecycle bash script: use Nix store bash (no /usr/bin/env in containers)
    substituteInPlace ${sp}/lifecycle/ak \
      --replace-fail '#!/usr/bin/env bash' '#!${pkgs.bash}/bin/bash'

    # --- Top-level structure ---
    ln -s ${sp}/lifecycle $out/lifecycle
    ln -s ${sp}/authentik $out/authentik
    cp -r blueprints $out/blueprints
    cp manage.py $out/manage.py

    runHook postInstall
  '';

  # CI is build-only, so fail the build if the venv layout regresses: run
  # the copied interpreter from / (no cwd masking) and require it to resolve
  # to this package with the workspace packages importable. -B: the check
  # must not write mtime-stamped .pyc into $out (nondeterministic output).
  doInstallCheck = true;
  installCheckPhase = ''
    cd / && $out/bin/python3.14 -B -c "import sys, guardian, django_channels_postgres, django_dramatiq_postgres, django_postgres_cache; assert sys.prefix == '$out', sys.prefix"
  '';

  dontPatchShebangs = true;
}
