# Red fixture: `npm ci` without --ignore-scripts runs the dependencies'
# install scripts — downloaded code executing inside the FOD.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "npm-ci-scripts";
  src = pkgs.fetchgit {
    url = "https://example.com/web.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  nativeBuildInputs = with pkgs; [ nodejs cacert ];

  buildPhase = ''
    npm ci
  '';

  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashMode = "recursive";
}
