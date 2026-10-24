# venv-lock-generator.nix — resolves the pinned authentik venv closure to
# pure data (rendered by the task into venv-lock.nix).
#
# FETCHER-ONLY, PURE EVAL — no derivation is built: `builtins.fetchGit` for
# the trio and the authentik source, plus the in-repo-pinned nixpkgs, so it
# runs wherever nix can eval. The nixpkgs import is pinned to x86_64-linux
# (the deployment target), so the output is platform-pinned: wheel selection
# and the PEP 508 markers follow that system, not the runner, and the
# rendered file matches on every runner.
#
# Invoked by mise-tasks/generate-authentik-venv-lock:
#   nix eval --extra-experimental-features nix-command flakes --impure --json \
#     --expr '(import <this-file>) (import <args.nix>)'
# where <args.nix> is the argument attrset below, rendered by the task.
#
# Arguments (one attrset):
#   nixpkgsPath     store path of the pinned nixpkgs (containers/flake.lock)
#   nixpkgsRev      the pinned nixpkgs rev (for provenance)
#   authentikUrl / authentikTag / authentikHash   (from sources.nix)
#   authentikSha    tag -> sha, resolved by the task at run time
#   trio            { pyproject-nix = {url,sha}; uv2nix = {url,sha}; build-system-pkgs = {url,sha}; }
#
# Returns a JSON-serialisable attrset:
#   { provenance = {…};
#     venv = { <name> = { version, fmt, source }; };
#     buildSystem = { <name> = { version, format, source }; }; }
{
  nixpkgsPath,
  nixpkgsRev,
  authentikUrl,
  authentikTag,
  authentikHash,
  authentikSha,
  trio,
}:

let
  # Pinned to the deployment target, not the runner: hostPlatform (wheel
  # selection) and the pep508 markers (sys_platform, platform_machine) both
  # follow this import's system, so the resolved closure is identical on the
  # x86_64-linux pod and the aarch64-darwin indri-build runner.
  pkgs = import (builtins.toPath nixpkgsPath) { system = "x86_64-linux"; };
  lib = pkgs.lib;

  # --- the pinned trio (the same revs python-deps.nix builds with) ---------
  pyproject-nix = import (builtins.fetchGit {
    url = trio.pyproject-nix.url;
    rev = trio.pyproject-nix.sha;
  }) { inherit lib; };
  uv2nix = import (builtins.fetchGit {
    url = trio.uv2nix.url;
    rev = trio.uv2nix.sha;
  }) { inherit lib pyproject-nix; };
  build-system-pkgs = import (builtins.fetchGit {
    url = trio.build-system-pkgs.url;
    rev = trio.build-system-pkgs.sha;
  }) { inherit lib pyproject-nix uv2nix; };

  # --- pinned authentik source (sources.nix tag, resolved to sha) ----------
  src = builtins.fetchGit {
    url = authentikUrl;
    rev = authentikSha;
  };

  python = pkgs.python314;
  inherit (pyproject-nix.lib) pypa pep508;
  lock1 = uv2nix.lib.lock1;

  parsedLock = lock1.parseLock (lib.importTOML (src + "/uv.lock"));
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };
  rootSpec = { authentik = [ ]; };
  environ = pep508.setEnviron (pep508.mkEnviron python) { extra = [ ]; };
  resolved = lock1.resolveDependencies {
    lock = lock1.filterConflicts { lock = parsedLock; spec = rootSpec; };
    inherit environ;
    dependencies = [ "authentik" ];
  };
  # Local workspace projects are excluded from the venv (authentik-django.nix
  # copies + patches them from the source tree — see python-deps.nix header).
  localNames = [
    "authentik"
    "ak-guardian"
    "django-channels-postgres"
    "django-dramatiq-postgres"
    "django-postgres-cache"
  ];
  venvNames = lib.sort builtins.lessThan
    (lib.filter (n: !lib.elem n localNames) (lib.attrNames resolved));

  # Reproduce uv2nix/lib/build.nix `remote`'s source preference (= "wheel") +
  # wheel selection exactly, so the recorded source matches the one the build
  # would fetch.
  cfg = workspace.config;
  preferWheel =
    pkg:
    if cfg.no-build then true
    else if cfg.no-binary then false
    else if lib.elem pkg.name cfg.no-binary-package then false
    else if lib.elem pkg.name cfg.no-build-package then true
    else true;
  platform = pkgs.stdenv.hostPlatform;
  parseGitURL =
    url:
    let
      m1 = lib.match "([^?]+)\\?([^#]+)#(.+)" url;
      m2 = lib.match "([^#]+)#(.+)" url;
    in
    if m1 != null then { url = lib.elemAt m1 0; rev = lib.elemAt m1 2; }
    else if m2 != null then { url = lib.elemAt m2 0; rev = lib.elemAt m2 1; }
    else throw "could not parse git url: ${url}";

  sourceOf =
    pkg:
    let
      wheelFiles = map (whl: whl.file') pkg.wheels;
      isGit = pkg.source ? git;
      isPypi = pkg.source ? registry;
      isURL = pkg.source ? url;
      compat = pypa.selectWheels platform python wheelFiles;
      fmt =
        if isGit then "git"
        else if isURL then (if pkg.sdist != { } then "sdist" else "wheel")
        else if isPypi then
          if preferWheel pkg && compat != [ ] then "wheel"
          else if pkg.sdist == { } then "wheel"
          else "sdist"
        else "sdist";
      selFile = if (fmt == "wheel" && compat != [ ]) then (lib.head compat) else null;
      selEntry =
        if selFile != null then
          lib.findFirst (whl: whl.file'.filename == selFile.filename)
            (throw "wheel ${selFile.filename} not found for ${pkg.name}")
            pkg.wheels
        else null;
    in
    {
      inherit (pkg) version;
      inherit fmt;
      source =
        if isGit then
          let g = parseGitURL pkg.source.git;
          in { type = "git"; inherit (g) url rev; }
        else if fmt == "wheel" then
          {
            type = "wheel";
            inherit (selEntry) url hash;
            platformTags = lib.sort builtins.lessThan selFile.platformTags;
          }
        else
          { type = "sdist"; inherit (pkg.sdist) url hash; };
    };

  # Tie each recorded source to what the current build actually fetches:
  # pythonSet is the same package set python-deps.nix overlays, so for every
  # venv package its <n>.src (a fetchurl/fetchGit — read, not built) must
  # carry exactly the recorded url/hash. The git sources are builtins.fetchGit
  # attrsets, which carry rev but not url; both sides derive from the same
  # uv.lock git entry, so rev is the selection-relevant pin. A
  # reimplementation drift from build.nix `remote` is a generation error, not
  # a silent lock.
  srcMatches =
    n: e:
    let
      s = pythonSet.${n}.src;
    in
    if e.source.type == "git" then
      s.rev == e.source.rev
    else
      s.url == e.source.url && s.hash == e.source.hash;

  # --- the venv closure ----------------------------------------------------
  venv = lib.listToAttrs (
    map (n:
      let
        e = sourceOf resolved.${n};
      in
      assert srcMatches n e;
      lib.nameValuePair n e
    ) venvNames
  );

  # --- sdist build-system closure -----------------------------------------
  # The sdist venv packages build with `uv build --no-build-isolation`, so
  # their PEP 517 build-systems must be installed first. The current build
  # resolves them via the build-system-pkgs overlay (python-deps.nix
  # sdistFixups: `final.resolveBuildSystem {setuptools|cython|pkgconfig}`);
  # all of them are prebuilt wheels. We record them here so the consumer can
  # install them without the trio.
  #
  # To read their sources we reconstruct the same package set the build uses
  # (callPackage packages + both overlays + the sdist fixups). Reading a
  # single package's `.src` attributes is pure eval — nothing is built.
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
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config final.lxml ]
          ++ setuptoolsBackend final ++ final.resolveBuildSystem { pkgconfig = [ ]; };
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
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ setuptoolsBackend final ++ final.resolveBuildSystem { cython = [ ]; };
        buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.krb5 ];
      });
    }
    // lib.optionalAttrs (prev ? "py-ubjson") {
      "py-ubjson" = prev."py-ubjson".overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ setuptoolsBackend final;
      });
    }
    // lib.optionalAttrs (prev ? "aws-cdk-cloud-assembly-schema") {
      "aws-cdk-cloud-assembly-schema" = prev."aws-cdk-cloud-assembly-schema".overrideAttrs (old: {
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
      build-system-pkgs.overlays.wheel
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; dependencies = rootSpec; })
      sdistFixups
    ]);

  sysSourceOf =
    name:
    let
      d = pythonSet.${name};
      s = d.src;
    in
    {
      inherit (d) version;
      format = d.passthru.format;
      source =
        if d.passthru.format == "wheel" then
          {
            type = "wheel";
            inherit (s) url hash;
            platformTags = lib.sort builtins.lessThan
              (pypa.parseWheelFileName (lib.baseNameOf s.url)).platformTags;
          }
        else if d.passthru.format == "pyproject" then
          { type = "sdist"; inherit (s) url hash; }
        else
          throw "unexpected build-system source format for ${name}";
    };

  buildSystem = lib.listToAttrs (
    map (n: lib.nameValuePair n (sysSourceOf n)) [ "setuptools" "cython" "pkgconfig" ]
  );
in
{
  provenance = {
    authentik = {
      url = authentikUrl;
      tag = authentikTag;
      hash = authentikHash;
      sha = authentikSha;
    };
    trio = lib.mapAttrs (_: t: { url = t.url; rev = t.sha; }) trio;
    nixpkgs = { rev = nixpkgsRev; };
    python = python.pythonVersion;
  };
  inherit venv buildSystem;
}
