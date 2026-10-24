let
  pkgs = import <nixpkgs> { };
in
let
src = pkgs.runCommand "fodcheck-npm-src" { } ''
  mkdir -p $out
  printf '{}\n' > $out/package.json
'';
in
pkgs.fetchNpmDeps {
name = "fodcheck-npm-deps";
src = src;
hash = pkgs.lib.fakeHash;
}
