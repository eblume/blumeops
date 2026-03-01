# Authentik Go HTTP server binary
#
# Builds cmd/server from the authentik source using buildGoModule.
# The compiled binary serves the web UI, REST API, spawns gunicorn
# for the Django backend, and runs the embedded reverse proxy outpost.
#
# Two runtime path dependencies are baked in at compile time:
#   - authentik-django: lifecycle scripts (gunicorn launcher)
#   - webui: static web assets (dist/ and authentik/ directories)
#
# The apiGoVendorHook replaces vendored goauthentik.io/api/v3 with
# freshly generated client-go output, but only during the real build
# (not the FOD module-download phase), so vendorHash stays stable.
#
# Output: $out/bin/authentik
{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
, authentik-django ? import ./authentik-django.nix { inherit pkgs sources; }
, webui ? null
}:

let
  apiGoVendorHook = import ./api-go-vendor-hook.nix { inherit pkgs sources; };

  # Web assets path: use real webui derivation if provided, otherwise
  # a placeholder directory. The placeholder allows the binary to compile
  # and pass --help verification, but web serving won't work at runtime.
  webAssetsPath =
    if webui != null then webui
    else pkgs.runCommand "webui-placeholder" { } ''
      mkdir -p $out/dist $out/authentik
    '';
in

pkgs.buildGoModule {
  pname = "authentik-server";
  inherit (sources) version src meta;

  subPackages = [ "cmd/server" ];

  nativeBuildInputs = [ apiGoVendorHook ];

  env.CGO_ENABLED = 0;

  postPatch = ''
    substituteInPlace internal/gounicorn/gounicorn.go \
      --replace-fail './lifecycle' "${authentik-django}/lifecycle"
    substituteInPlace web/static.go \
      --replace-fail './web' "${webAssetsPath}"
    substituteInPlace internal/web/static.go \
      --replace-fail './web' "${webAssetsPath}"
  '';

  # Clear postPatch during the module-download FOD phase so that
  # substituteInPlace (which references authentik-django and webui
  # store paths) doesn't affect vendorHash computation.
  overrideModAttrs.postPatch = "";

  vendorHash = "sha256-bdILiCQgDuzp+VJDVW3z2JxTtxlHkm9tmMHiA/Sx6ts=";

  postInstall = ''
    mv $out/bin/server $out/bin/authentik
  '';
}
