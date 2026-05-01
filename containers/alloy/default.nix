# Nix-built Grafana Alloy telemetry collector
# Builds v1.16.0 from forge mirror with embedded web UI
# Uses stdenv + make (not buildGoModule) due to multi-module workspace
# with local replace directives (collector/ -> ../, ../syntax, ../extension)
# Built with dockerTools.buildLayeredImage for efficient layer caching
{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.16.0";

  src = pkgs.fetchgit {
    url = "https://forge.ops.eblu.me/mirrors/alloy.git";
    rev = "v${version}";
    hash = "sha256-q5R2noxBZ3OPyZqmB+bx3iJKWFxC2WIprcgh9RwjLzk=";
  };

  ui = pkgs.buildNpmPackage {
    inherit version;
    pname = "alloy-ui";
    src = "${src}/internal/web/ui";
    npmDepsHash = "sha256-vResNUT4auDsK9ngnJYfMUUOYr/ikPhrvakqCjGq2Q8=";

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
    outputHash = "sha256-9/v85HyDInJB+9qHauKVuDol6Yf5mkXfMWgCr7RdRTk=";
    outputHashAlgo = "sha256";
  };

  alloy = pkgs.stdenv.mkDerivation {
    inherit src version;
    pname = "alloy";

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

      # Build using upstream Makefile
      # promtail_journal_enabled omitted: requires systemd headers
      # and our k8s deployments read pod logs from the filesystem, not journald
      RELEASE_BUILD=1 \
        VERSION=v${version} \
        GO_TAGS="netgo embedalloyui" \
        SKIP_UI_BUILD=1 \
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
