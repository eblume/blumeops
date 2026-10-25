let
  pkgs = import <nixpkgs> { };
in
pkgs.pkgsCross.wasi32.fetchgit {
url = "https://example.com/repo.git";
rev = "61f98e459f7f9d5fad6a79992f0dd310de359e10";
hash = pkgs.lib.fakeHash;
}
