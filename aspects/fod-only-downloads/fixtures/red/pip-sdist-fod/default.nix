# Red fixture: building sdists with pip inside the FOD — the build backends
# (setuptools, Cython, C compilers) are downloaded code executing in the FOD.
# This is the shape the authentik python-deps FOD had before eblume/blumeops#1813.
{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "pip-in-fod";
  src = pkgs.fetchgit {
    url = "https://example.com/py.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };

  nativeBuildInputs = with pkgs; [ python314 ];

  buildPhase = ''
    pip install .
  '';

  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashMode = "recursive";
}
