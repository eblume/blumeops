# Python dependency venv for authentik.
#
# No FOD: every artifact in uv.lock is a hashed fetchurl (wheel), and the
# packages without a compatible wheel build from sdist as ordinary sandboxed
# PEP 517 derivations. uv2nix parses uv.lock and the workspace pyproject.tomls
# in pure Nix at eval time; there are no generated files to check in and no
# fakeHash round when the lock changes.
#
# The local workspace projects (and the root project) are excluded from the
# venv: authentik-django.nix copies them from the monorepo source and patches
# them, so the venv must contain exactly the third-party closure of the root
# project's dependencies.
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

let
  lib = pkgs.lib;

  # Pinning the trio that turns uv.lock into Nix (kept in sync by hand; no
  # flake inputs here, same as the rest of containers/).
  pyproject-nix = import (pkgs.fetchgit {
    url = "https://github.com/pyproject-nix/pyproject.nix.git";
    rev = "ddc400a6883b042646d0940e65971bb7f7e96107";
    hash = "sha256-vcCAvhtA7hG+/gOge29hYHy7I/dLkIsr5nLx4sFEQic=";
  }) { inherit lib; };

  uv2nix = import (pkgs.fetchgit {
    url = "https://github.com/pyproject-nix/uv2nix.git";
    rev = "7aba73a3d85454f1118f8cf9de97979b4d26bcac";
    hash = "sha256-PMtgvHuGijoIAtPtrBm7kJOI6fxzX4LYPAIK+QVGY+Y=";
  }) { inherit lib pyproject-nix; };

  pyproject-build-systems = import (pkgs.fetchgit {
    url = "https://github.com/pyproject-nix/build-system-pkgs.git";
    rev = "a17819c85163988e063806ffc4f6d2716bc8ead8";
    hash = "sha256-mGOkvueuMGSRiD75ccxFzfEvSlIU9ztjFluHMKOtogY=";
  }) { inherit lib pyproject-nix uv2nix; };

  python = pkgs.python314;

  lock1 = uv2nix.lib.lock1;

  parsedLock = lock1.parseLock (lib.importTOML (sources.src + "/uv.lock"));

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = sources.src; };

  # Must stay in lockstep with the overlay's `dependencies` below: the venv
  # spec is computed from the same resolution the overlay builds.
  rootSpec = { authentik = [ ]; };
  environ = pyproject-nix.lib.pep508.setEnviron
    (pyproject-nix.lib.pep508.mkEnviron python)
    { extra = [ ]; };
  resolved = lock1.resolveDependencies {
    lock = lock1.filterConflicts { lock = parsedLock; spec = rootSpec; };
    inherit environ;
    dependencies = [ "authentik" ];
  };
  localNames = [
    "authentik"
    "ak-guardian"
    "django-channels-postgres"
    "django-dramatiq-postgres"
    "django-postgres-cache"
  ];
  venvSpec = lib.mapAttrs (_: _: [ ]) (lib.filterAttrs (name: _: !lib.elem name localNames) resolved);

  # The sdist packages are the ones without a cp314/manylinux wheel (or
  # forced by [tool.uv] no-binary-package); their PEP 517 builds are plain C
  # compiles and need the system libraries the old FOD put on PATH. The
  # nixpkgs interpreter ships no setuptools, so every setuptools-backend sdist
  # also needs the build-system package from the build-systems overlay.
  setuptoolsBackend = final: final.resolveBuildSystem { setuptools = [ ]; };
  sdistFixups = final: prev:
    lib.optionalAttrs (prev ? lxml) {
      lxml = prev.lxml.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ] ++ setuptoolsBackend final;
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libxml2 pkgs.libxslt pkgs.zlib ];
      });
    }
    // lib.optionalAttrs (prev ? xmlsec) {
      xmlsec = prev.xmlsec.overrideAttrs (old: {
        # build_ext.py has two undeclared build deps (uv's isolated builds used
        # to provide both): the Python pkgconfig module (pulled from the
        # build-systems set like setuptools) and lxml itself, imported for its
        # headers via lxml.get_include()
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config final.lxml ]
          ++ setuptoolsBackend final ++ final.resolveBuildSystem { pkgconfig = [ ]; };
        # The Python pkgconfig module shells out to a nix pkg-config wrapper
        # that resolves the runtime PKG_CONFIG_PATH. xmlsec1.pc Requires
        # libxml-2.0 and libxslt, so all four .pc dirs must be visible.
        postConfigure = (old.postConfigure or "") + ''
          export PKG_CONFIG_PATH="${pkgs.xmlsec.dev}/lib/pkgconfig:${pkgs.libxml2.dev}/lib/pkgconfig:${pkgs.libxslt.dev}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig"
        '';
        # libtool provides libltdl, which xmlsec's dynamic crypto backend loads
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.xmlsec pkgs.openssl pkgs.libtool pkgs.zlib pkgs.libffi ];
      });
    }
    // lib.optionalAttrs (prev ? "psycopg-c") {
      "psycopg-c" = prev."psycopg-c".overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.postgresql.pg_config ] ++ setuptoolsBackend final;
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libpq ];
      });
    }
    // lib.optionalAttrs (prev ? gssapi) {
      gssapi = prev.gssapi.overrideAttrs (old: {
        # setup.py imports cythonize unconditionally (pre-generated C code)
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ setuptoolsBackend final ++ final.resolveBuildSystem { cython = [ ]; };
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.krb5 ];
        # gssapi's pre-generated C code uses S4U prototypes without including
        # gssapi_ext.h; force-include it (same workaround as the old FOD)
        NIX_CFLAGS_COMPILE = "-include gssapi/gssapi_ext.h";
      });
    }
    // lib.optionalAttrs (prev ? "py-ubjson") {
      "py-ubjson" = prev."py-ubjson".overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ setuptoolsBackend final;
      });
    }
    // lib.optionalAttrs (prev ? "aws-cdk-cloud-assembly-schema") {
      "aws-cdk-cloud-assembly-schema" = prev."aws-cdk-cloud-assembly-schema".overrideAttrs (old: {
        # aws-cdk-lib vendors its own aws_cdk.cloud_assembly_schema (a different
        # jsii build with a different _jsii import path). uv installs the
        # standalone first, then aws-cdk-lib overwrites the shared file
        # (last-wins). make-venv's merge can't express last-wins, so drop the
        # colliding file here; the merge then keeps aws-cdk-lib's copy.
        postInstall = (old.postInstall or "") + ''
          rm -f "$out/lib/python3.14/site-packages/aws_cdk/cloud_assembly_schema/__init__.py"
        '';
      });
    }
    // lib.optionalAttrs (prev ? opencontainers) {
      opencontainers = prev.opencontainers.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ setuptoolsBackend final;
      });
    };

  pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; })
    .overrideScope (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; dependencies = rootSpec; })
      sdistFixups
    ]);

in

# One file collision remains in the locked closure: a top-level docs/Makefile
# shipped by both django-tenants and pyrad (unrelated doc-build files, either
# copy is fine). Let make-venv link the first-encountered copy. (The
# aws_cdk.cloud_assembly_schema conflict is handled by the
# aws-cdk-cloud-assembly-schema override above.)
(pythonSet.mkVirtualEnv "authentik-python-deps" venvSpec)
  .overrideAttrs (old: {
    venvIgnoreCollisions = [
      "lib/python3.14/site-packages/docs/Makefile"
    ];
  })
