# Authentik web UI build
#
# Builds the Lit-based TypeScript frontend from the web/ directory.
# Uses esbuild (via wireit) for the main build and rollup for the SFE
# (Standalone Frontend Engine) sub-package.
#
# Inputs:
#   - webui-deps: FOD with npm dependencies (node_modules trees)
#   - client-ts: generated TypeScript API client from schema.yml
#
# Output:
#   $out/dist/        esbuild bundle (admin, user, flow, rac, etc.)
#   $out/authentik/   static icons for authentication sources/connectors
{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
, webui-deps ? import ./webui-deps.nix { inherit pkgs sources; }
, client-ts ? import ./client-ts.nix { inherit pkgs sources; }
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "authentik-webui";
  inherit (sources) version src meta;

  sourceRoot = "${sources.src.name}/web";

  nativeBuildInputs = with pkgs; [
    nodejs_24
  ];

  # Hardcode version string instead of importing from package.json
  # (the JSON import-with-assertion may not resolve in the Nix build sandbox)
  postPatch = ''
    substituteInPlace packages/core/version/node.js \
      --replace-fail \
        'import PackageJSON from "../../../../package.json" with { type: "json" };' \
        "" \
      --replace-fail \
        '(PackageJSON.version);' \
        '"${sources.version}";'
  '';

  buildPhase = ''
    runHook preBuild

    # Copy node_modules from the FOD into the build tree
    buildRoot=$PWD
    pushd ${webui-deps}
    find -type d -name node_modules -prune -print \
      -exec cp -rT {} $buildRoot/{} \;
    popd

    # Replace the npm-published @goauthentik/api with our generated client
    chmod -R +w node_modules/@goauthentik
    rm -rf node_modules/@goauthentik/api
    ln -sn ${client-ts} node_modules/@goauthentik/api

    # Patch shebangs on build tool binaries so they can run in the sandbox
    pushd node_modules/.bin
    for tool in rollup wireit lit-localize esbuild; do
      [ -L "$tool" ] && patchShebangs "$(readlink "$tool")" 2>/dev/null || true
    done
    popd

    npm run build
    npm run build:sfe

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir $out
    cp -r dist $out/dist
    cp -r authentik $out/authentik
    runHook postInstall
  '';

  NODE_ENV = "production";
  NODE_OPTIONS = "--openssl-legacy-provider";
}
