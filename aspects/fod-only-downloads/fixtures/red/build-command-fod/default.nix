# Red fixture: buildCommand is the attr runCommand sets - writing it
# directly in an mkDerivation FOD skips no check: every string attr of a
# FOD except the inert allowlist is graded (eblume/blumeops#1809).
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "build-command-fod";
  src = pkgs.fetchurl {
    url = "https://example.com/thing-1.0.tar.gz";
    sha256 = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  buildCommand = ''
    make install
  '';

  outputHashMode = "recursive";
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashAlgo = "sha256";
}
