# Green fixture: fetcher primitives and the builderless pure-fetch FOD
# shape — no shell at all.
{ pkgs ? import <nixpkgs> { } }:

let
  tarball = pkgs.fetchurl {
    url = "https://example.com/thing-1.0.tar.gz";
    sha256 = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };
  git = pkgs.fetchGit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  };
  pureFetch = derivation {
    builder = null;
    args = [ tarball.url "sha256-0000000000000000000000000000000000000000000000000000000000000000=" ];
    fixedOutput = true;
  };
in
pureFetch + git
