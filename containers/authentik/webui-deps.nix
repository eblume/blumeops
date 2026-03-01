# Fixed-output derivation for authentik web UI npm dependencies
#
# Runs `npm ci` in the web/ directory to fetch all Node.js dependencies.
# This is a FOD (fixed-output derivation) so it has network access during build
# but the output hash must match exactly.
#
# The output hash is platform-specific because npm downloads platform-specific
# native binaries for esbuild, rollup, and SWC.
#
# Workspace packages (under web/packages/*) have their own node_modules,
# so we collect all node_modules directories via find.
#
# Output: all node_modules directories from the web/ tree
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "authentik-webui-deps";
  inherit (sources) version src meta;

  sourceRoot = "${sources.src.name}/web";

  outputHash =
    {
      "x86_64-linux" = "sha256-+4cWvFuixCcO7P+z701/0H+Ah/Z5sbLNsdx2Uowqwf4=";
    }
    .${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "authentik-webui-deps: unsupported host platform ${pkgs.stdenvNoCC.hostPlatform.system}");
  outputHashMode = "recursive";

  nativeBuildInputs = with pkgs; [
    nodejs_24
    cacert
  ];

  buildPhase = ''
    npm ci --cache ./cache --ignore-scripts
    rm -r ./cache node_modules/.package-lock.json
  '';

  # Workspace packages install dependencies into separate node_modules
  # directories with symlinks between them — copy all of them
  installPhase = ''
    mkdir $out
    find -type d -name node_modules -prune -print \
      -exec mkdir -p $out/{} \; \
      -exec cp -rT {} $out/{} \;
  '';

  dontCheckForBrokenSymlinks = true;
  dontPatchShebangs = true;
}
