# Red: a local setup hook that registers without the FOD guard would run
# its script during the vendor FOD.
{ pkgs ? import <nixpkgs> { } }:

let
  evilHook = import ./hook.nix { inherit pkgs; };
in
pkgs.buildGoModule {
  pname = "x";
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  nativeBuildInputs = [ evilHook ];
}
