# Nix-built Kingfisher secret scanner
# Built from upstream main + sporked feature branches applied as patches.
# Runs on ringtail (amd64) via nix-container-builder runner.
#
# How it works:
#   1. builtins.fetchGit fetches upstream and feature branches at eval time
#   2. diff generates patches from upstream→feature in a sandboxed derivation
#   3. buildRustPackage applies patches to the upstream source and builds
#
# To update:
#   1. Update upstreamRev to the new main SHA
#   2. Rebase feature branches onto new main (mirror-sync does this daily)
#   3. Update feature revs to the new rebased SHAs
#   4. Update Cargo.lock if dependencies changed
#
# The upstream rev must be an ancestor of each feature rev.
{ pkgs ? import <nixpkgs> { } }:

let
  version = "165768b";
  repoUrl = "https://forge.ops.eblu.me/eblume/kingfisher.git";

  upstreamRev = "165768b5ca9a85c2e8c64bed19bb197e82b45360";

  features = [
    {
      name = "clone-url-base";
      ref = "feature/upstream/clone-url-base";
      rev = "4d5ce57a12650ec54c41b909f8623a1d395aa0a9";
    }
  ];

  # Fetch upstream source at the pinned rev (eval-time, network access)
  upstreamSrc = builtins.fetchGit {
    url = repoUrl;
    ref = "main";
    rev = upstreamRev;
  };

  # Fetch each feature branch source and generate a patch against upstream
  featurePatches = map (f:
    let
      featureSrc = builtins.fetchGit {
        url = repoUrl;
        ref = f.ref;
        rev = f.rev;
      };
    in
    pkgs.runCommand "spork-${f.name}.patch" {
      nativeBuildInputs = [ pkgs.diffutils pkgs.gnused ];
    } ''
      diff -ruN --no-dereference ${upstreamSrc} ${featureSrc} \
        | sed -e 's|${upstreamSrc}/|a/|g' -e 's|${featureSrc}/|b/|g' \
        > $out || true
    ''
  ) features;

  kingfisher = pkgs.rustPlatform.buildRustPackage {
    pname = "kingfisher";
    inherit version;
    src = upstreamSrc;

    patches = featurePatches;

    # Cargo.lock is not committed upstream; we vendor a copy alongside default.nix
    cargoLock.lockFile = ./Cargo.lock;

    # Patch the source to include Cargo.lock (buildRustPackage needs it in-tree)
    postPatch = ''
      cp ${./Cargo.lock} Cargo.lock
      chmod +w Cargo.lock
    '';

    nativeBuildInputs = with pkgs; [
      cmake
      pkg-config
      python3
    ];

    buildInputs = with pkgs; [
      boost
      openssl
    ];

    # Don't run tests — they need network access for wiremock
    doCheck = false;

    meta = with pkgs.lib; {
      description = "Secret detection and live validation tool";
      homepage = "https://github.com/mongodb/kingfisher";
      license = licenses.asl20;
      mainProgram = "kingfisher";
    };
  };
in

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/kingfisher";
  contents = [
    kingfisher
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.cacert
    pkgs.git
    pkgs.tzdata
  ];

  extraCommands = ''
    mkdir -p tmp
    chmod 1777 tmp
  '';

  config = {
    Entrypoint = [ "${kingfisher}/bin/kingfisher" ];
    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "TZDIR=${pkgs.tzdata}/share/zoneinfo"
      "TMPDIR=/tmp"
    ];
    User = "65534";
  };
}
