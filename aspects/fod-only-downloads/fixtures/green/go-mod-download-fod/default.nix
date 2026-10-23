# Green fixture: the allowlisted go fetch mode — `go mod download` prefills
# the module cache, like the goModules derivation in
# containers/alloy/default.nix.
{ pkgs ? import <nixpkgs> { } }:

let
  src = pkgs.fetchgit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "go-modules";
  inherit src;

  nativeBuildInputs = with pkgs; [ go_1_26 git cacert ];

  buildPhase = ''
    export GOPATH=$TMPDIR/go
    export GOFLAGS=-modcacherw
    export GOTOOLCHAIN=local
    go mod download
    cd syntax && go mod download && cd ..
    cd collector && go mod download && cd ..
  '';

  installPhase = ''
    cp -r $TMPDIR/go/pkg/mod $out
  '';

  outputHashMode = "recursive";
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashAlgo = "sha256";
}
