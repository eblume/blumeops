# Green: a local setup hook accepted on its merits - the script registers
# its hooks only under `if [ -z ${outputHash-} ]`, so it is inert in the
# vendor FOD (the containers/authentik/api-go-vendor-hook.nix shape).
{ pkgs ? import <nixpkgs> { } }:

let
  apiGoVendorHook = import ./hook.nix { inherit pkgs; };
in
pkgs.buildGoModule {
  pname = "x";
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  nativeBuildInputs = [ apiGoVendorHook ];
}
