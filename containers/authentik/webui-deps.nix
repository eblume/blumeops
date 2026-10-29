# Fixed-output derivation for authentik web UI npm dependencies
#
# Runs `pnpm install --frozen-lockfile` in the web/ directory (upstream moved
# web/ from npm to a pnpm workspace in 2026.8) to fetch all Node.js dependencies.
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
      "x86_64-linux" = pkgs.lib.fakeHash;
    }
    .${pkgs.stdenvNoCC.hostPlatform.system}
      or (throw "authentik-webui-deps: unsupported host platform ${pkgs.stdenvNoCC.hostPlatform.system}");
  outputHashMode = "recursive";

  nativeBuildInputs = with pkgs; [
    nodejs_26
    pnpm_11
    cacert
  ];

  # Upstream symlinks web/packages/client-ts -> ../../packages/client-ts.
  # stdenv only makes sourceRoot (web/) writable, so pnpm EACCESes on the target.
  postUnpack = ''
    chmod -R u+w -- "$sourceRoot/../packages/client-ts"
  '';

  # Keep pnpm from fetching the packageManager-pinned version at runtime (the
  # sandbox has no network); the nixpkgs pnpm_11 is used as-is.
  buildPhase = ''
    export HOME=$TMPDIR
    export npm_config_manage_package_manager_versions=false
    pnpm install --frozen-lockfile --ignore-scripts --store-dir ./pnpm-store
    rm -r ./pnpm-store
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
