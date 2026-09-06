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
    npmDepsHash = pkgs.lib.fakeHash;

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

  # Beyla eBPF binaries (v3.28.0), pinned by the alloy source's in-tree
  # internal/component/beyla/ebpf/internal/config/gen/beyla/beyla_version.yaml
  # (sha256s verified against the grafana/beyla release tarballs). The
  # Makefile's `beyla` prerequisite (a dependency of `alloy` since v1.19.0)
  # downloads these into internal/component/beyla/ebpf/binaries/<arch>/beyla
  # for go:embed into the alloy binary. Pre-placing the binaries and the
  # version stamp makes that download a no-op, so the build needs no
  # network for beyla.
  beyla-version = "v3.28.0";

  beyla-amd64 = pkgs.fetchurl {
    url = "https://github.com/grafana/beyla/releases/download/${beyla-version}/beyla-linux-amd64-${beyla-version}.tar.gz";
    sha256 = "ea4c1dac9fe8fd2261f021efe37adbed41307bfb5da0e48f5ee80d6d9b6e620e";
  };

  beyla-arm64 = pkgs.fetchurl {
    url = "https://github.com/grafana/beyla/releases/download/${beyla-version}/beyla-linux-arm64-${beyla-version}.tar.gz";
    sha256 = "227cd13304c264c5c00df720df6afc70b396ee3471df8e1140b8903cc87787e9";
  };

  # Extracts the beyla binary from each tarball (root member "beyla") and
  # writes the .beyla-binary-version stamp that the Makefile's download.go
  # upToDate check compares against beyla_version.yaml.
  beyla-binaries = pkgs.stdenv.mkDerivation {
    pname = "beyla-binaries";
    version = beyla-version;
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
    src = null;

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
    outputHash = pkgs.lib.fakeHash;
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
