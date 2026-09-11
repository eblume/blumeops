# Nix-built Grafana Alloy telemetry collector
# Builds v1.19.2 from forge mirror with embedded web UI
# Uses stdenv + make (not buildGoModule) due to multi-module workspace
# with local replace directives (collector/ -> ../, ../syntax, ../extension)
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.19.2";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/alloy.git";
    rev = "v${version}";
    hash = "sha256-GllAidIhgLx9ciQ/57wV1cKyzsXvEAGRgv3+8x6Uq9M=";
  };

  ui = pkgs.buildNpmPackage {
    inherit version;
    pname = "alloy-ui";
    src = "${src}/internal/web/ui";
    npmDepsHash = "sha256-vrJUH76B0Zzuqh7Ri7B2K9YoX30xO//G0/opfYC/GTE=";

    buildPhase = ''
      runHook preBuild
      npx tsc -b
      npx vite build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/dist
      cp -r dist/* $out/dist/
      runHook postInstall
    '';
  };

  # Beyla eBPF binaries (v3.33.0). The alloy source's in-tree
  # internal/component/beyla/ebpf/internal/config/gen/beyla/beyla_version.yaml
  # pins v3.28.0, whose vendored OBI predates the uprobe-preemption guard
  # (OBI #3059, fixed in OBI v0.12.1) that stopped the 2026-09-10 ringtail
  # kernel panic; v3.33.0's OBI pin carries the fix. The Makefile's `beyla`
  # prerequisite (a dependency of `alloy` since v1.19.0) downloads the
  # version named in that file into
  # internal/component/beyla/ebpf/binaries/<arch>/beyla for go:embed into
  # the alloy binary. Pre-placing these binaries plus the version stamp,
  # and re-pinning the in-tree file to match (below), makes the download a
  # no-op, so the build needs no network for beyla.
  beyla-version = "v3.33.0";
  beyla-amd64-sha = "a6ae6a18774633a941e8f636d41a1836c8edd4f10fe9f4620b8a4bcbb3a5ed2f";
  beyla-arm64-sha = "4f5b56a521d01f59ae38f06dec196d05be2c1441ded20d957349ab5ad5dfa3a7";

  beyla-amd64 = pkgs.fetchurl {
    url = "https://github.com/grafana/beyla/releases/download/${beyla-version}/beyla-linux-amd64-${beyla-version}.tar.gz";
    sha256 = beyla-amd64-sha;
  };

  beyla-arm64 = pkgs.fetchurl {
    url = "https://github.com/grafana/beyla/releases/download/${beyla-version}/beyla-linux-arm64-${beyla-version}.tar.gz";
    sha256 = beyla-arm64-sha;
  };

  # Extracts the beyla binary from each tarball (root member "beyla") and
  # writes the .beyla-binary-version stamp that the Makefile's download.go
  # upToDate check compares against beyla_version.yaml.
  beyla-binaries = pkgs.stdenv.mkDerivation {
    pname = "beyla-binaries";
    version = beyla-version;
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
    # No source: the inputs are the two fetchurl tarballs. Without this the
    # default unpackPhase aborts on "$src or $srcs should point to the source".
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      mkdir -p $out/binaries/amd64 $out/binaries/arm64
      tar -xzf ${beyla-amd64} -C $out/binaries/amd64 beyla
      tar -xzf ${beyla-arm64} -C $out/binaries/arm64 beyla
      chmod 0755 $out/binaries/amd64/beyla $out/binaries/arm64/beyla
      echo "${beyla-version}" > $out/.beyla-binary-version
      runHook postBuild
    '';
  };

  # Pre-fetch Go modules for all three go.mod files (fixed-output derivation)
  goModules = pkgs.stdenv.mkDerivation {
    pname = "alloy-go-modules";
    inherit src version;

    nativeBuildInputs = with pkgs; [ go_1_26 git cacert ];

    buildPhase = ''
      export GOPATH=$TMPDIR/go
      export GOFLAGS=-modcacherw
      export GOTOOLCHAIN=local
      # Download modules for all three go.mod files
      go mod download
      cd syntax && go mod download && cd ..
      cd collector && go mod download && cd ..
    '';

    installPhase = ''
      cp -r $TMPDIR/go/pkg/mod $out
    '';

    outputHashMode = "recursive";
    outputHash = "sha256-+8CEVQ+eiJIvTRz3Y1RrKP3J38THYWTMKLjZYRqhKig=";
    outputHashAlgo = "sha256";
  };

  alloy = pkgs.stdenv.mkDerivation {
    inherit src version;
    pname = "alloy";

    # go_1_26 must satisfy the v1.19.2 go.mod directive (go 1.26.7)
    nativeBuildInputs = with pkgs; [
      go_1_26
      git
      gnumake
      cacert
    ];

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR
      export GOPATH=$TMPDIR/go
      export GOFLAGS=-modcacherw
      export GOTOOLCHAIN=local

      # Populate module cache from pre-fetched modules
      mkdir -p $GOPATH/pkg
      cp -r ${goModules} $GOPATH/pkg/mod
      chmod -R u+w $GOPATH/pkg/mod

      # Copy pre-built web UI assets
      cp -r ${ui}/dist/ internal/web/ui/dist

      # Pre-place the Beyla binaries and version stamp so the Makefile's
      # download-beyla step sees them as up to date (no build-time download)
      cp -a ${beyla-binaries}/binaries/. internal/component/beyla/ebpf/binaries/
      cp -a ${beyla-binaries}/.beyla-binary-version internal/component/beyla/ebpf/

      # Re-pin the in-tree beyla_version.yaml to the shipped version: the
      # Makefile's download.go reads that file as its trust anchor and would
      # otherwise re-download (overwriting) the version it names.
      printf '# Beyla release pinned by Alloy. Regenerate with: make update-beyla TAG=<beyla-version>\nversion: %s\nchecksums:\n  amd64: %s\n  arm64: %s\n' \
        "${beyla-version}" "${beyla-amd64-sha}" "${beyla-arm64-sha}" \
        > internal/component/beyla/ebpf/internal/config/gen/beyla/beyla_version.yaml

      # Build using upstream Makefile
      # promtail_journal_enabled omitted: requires systemd headers
      # and our k8s deployments read pod logs from the filesystem, not journald
      RELEASE_BUILD=1 \
        VERSION=v${version} \
        GO_TAGS="netgo embedalloyui" \
        SKIP_UI_BUILD=1 \
        SKIP_CODE_GENERATION=1 \
        make alloy

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp build/alloy $out/bin/alloy
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "OpenTelemetry Collector distribution with programmable pipelines";
      homepage = "https://grafana.com/docs/alloy/";
      license = licenses.asl20;
      mainProgram = "alloy";
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/alloy";
  contents = [
    alloy
    pkgs.cacert
    pkgs.tzdata
  ];

  config = {
    Entrypoint = [ "${alloy}/bin/alloy" ];
    Cmd = [ "run" "/etc/alloy/config.alloy" "--storage.path=/var/lib/alloy/data" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "ALLOY_DEPLOY_MODE=docker"
    ];
    ExposedPorts = {
      "12345/tcp" = { };
    };
    User = "65534";
  };
}
