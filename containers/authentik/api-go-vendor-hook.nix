# Setup hook that injects generated Go API client into the vendor directory
# Replaces vendor/goauthentik.io/api/v3/ with freshly generated client-go output
# Skips during FOD (fixed-output derivation) builds to keep vendorHash stable
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

let
  client-go = import ./client-go.nix { inherit pkgs sources; };
in
pkgs.makeSetupHook
  {
    name = "authentik-api-go-vendor-hook";
  }
  (
    pkgs.writeShellScript "authentik-api-go-vendor-hook" ''
      authentikApiGoVendorHook() {
        chmod -R +w vendor/goauthentik.io/api
        rm -rf vendor/goauthentik.io/api/v3
        cp -r ${client-go} vendor/goauthentik.io/api/v3

        echo "Finished authentikApiGoVendorHook"
      }

      # don't run for FOD, e.g. the goModules build
      if [ -z ''${outputHash-} ]; then
        postConfigureHooks+=(authentikApiGoVendorHook)
      fi
    ''
  )
