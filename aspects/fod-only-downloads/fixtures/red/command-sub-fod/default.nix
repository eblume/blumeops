# Red fixture: command substitution executes the substituted command inside
# the FOD, even though the head of the line is harmless plumbing.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "substitutes-in-fod";
  src = pkgs.fetchgit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  buildPhase = ''
    echo "build: $(go version)"
  '';

  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashMode = "recursive";
}
