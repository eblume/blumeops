# Red fixture: compiling inside a FOD. The fetched source is built with
# make while the derivation still has network — exactly what the invariant
# forbids (compile in a normal derivation instead).
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "compiles-in-fod";
  src = pkgs.fetchurl {
    url = "https://example.com/thing-1.0.tar.gz";
    sha256 = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  buildPhase = ''
    make all
  '';

  outputHashMode = "recursive";
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashAlgo = "sha256";
}
