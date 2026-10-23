{ pkgs ? import <nixpkgs> { }, client ? pkgs.fetchurl { url = "https://example.com/api"; hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; } }:

pkgs.makeSetupHook
  {
    name = "api-go-vendor-hook";
  }
  (
    pkgs.writeShellScript "api-go-vendor-hook" ''
      apiGoVendorHook() {
        chmod -R +w vendor/goauthentik.io/api
        rm -rf vendor/goauthentik.io/api/v3
        cp -r ${client} vendor/goauthentik.io/api/v3
      }

      # don't run for FOD, e.g. the goModules build
      if [ -z ''${outputHash-} ]; then
        postConfigureHooks+=(apiGoVendorHook)
      fi
    ''
  )
