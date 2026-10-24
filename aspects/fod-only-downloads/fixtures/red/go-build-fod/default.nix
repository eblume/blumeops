# Red fixture: `go build` compiles fetched module code inside the FOD.
# Only `go mod download` is an allowlisted fetch mode.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "go-builds-in-fod";
  src = pkgs.fetchgit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  nativeBuildInputs = with pkgs; [ go_1_26 ];

  buildPhase = ''
    go build ./...
  '';

  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashMode = "recursive";
}
