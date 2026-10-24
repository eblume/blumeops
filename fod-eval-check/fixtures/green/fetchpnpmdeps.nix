let
  pkgs = import <nixpkgs> { };
in
let
src = pkgs.runCommand "fodcheck-pnpm-src" { } ''
  mkdir -p $out
  printf '{}\n' > $out/package.json
  printf 'lockfileVersion: 9.0\n' > $out/pnpm-lock.yaml
'';
in
pkgs.fetchPnpmDeps {
pname = "fodcheck-pnpm-deps";
version = "0.0.0";
src = src;
hash = pkgs.lib.fakeHash;
fetcherVersion = 3;
}

