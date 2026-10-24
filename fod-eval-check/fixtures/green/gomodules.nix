let
  pkgs = import <nixpkgs> { };
in
let
src = pkgs.runCommand "fodcheck-go-src" { } ''
  mkdir -p $out
  printf 'module fodcheck\n\ngo 1.21\n' > $out/go.mod
'';
in
(pkgs.buildGoModule {
pname = "fodcheck-go-modules";
version = "0.0.0";
src = src;
vendorHash = pkgs.lib.fakeHash;
}).goModules
