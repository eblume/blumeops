# Red fixture: a custom phase named in prePhases and defined inline. A
# phase-name allowlist would miss it; the phase body is a string attr of
# the FOD and gets graded (eblume/blumeops#1809).
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "custom-phase-fod";
  src = pkgs.fetchurl {
    url = "https://example.com/thing-1.0.tar.gz";
    sha256 = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  prePhases = [ "generateAssets" ];
  generateAssets = ''
    ./configure
  '';

  outputHashMode = "recursive";
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashAlgo = "sha256";
}
