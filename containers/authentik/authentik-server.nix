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
# Output: $out/bin/authentik-server (the name lifecycle/ak execs)
{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
, authentik-django ? import ./authentik-django.nix { inherit pkgs sources; }
, webui ? null
}:

let
  # Web assets path: use real webui derivation if provided, otherwise
  # a placeholder directory. The placeholder allows the binary to compile
  # and pass --help verification, but web serving won't work at runtime.
  webAssetsPath =
    if webui != null then webui
    else pkgs.runCommand "webui-placeholder" { } ''
      mkdir -p $out/dist $out/authentik
    '';
in

# Go 1.27 ahead of the 2026.8.x step: its go.mod declares `go 1.27.0`,
# which the default nixpkgs go (1.26.x) refuses under GOTOOLCHAIN=local.
(pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
  pname = "authentik-server";
  inherit (sources) version src meta;

  subPackages = [ "cmd/server" ];

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
  overrideModAttrs = _finalAttrs: _prevAttrs: {
    postPatch = "";
  };

  vendorHash = "sha256-EVDOZ4USaJoIBDB8mM4ZSBfsSc1d/NOm1Qv/hUJ+8f4=";

  postInstall = ''
    mv $out/bin/server $out/bin/authentik-server
  '';
}
