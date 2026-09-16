# Generate TypeScript fetch client bindings from authentik's OpenAPI schema
# Uses openapi-generator-cli to produce TypeScript code, then compiles with tsc
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "authentik-client-ts";
  inherit (sources) version src meta;

  # Docker volume path /local → local pwd
  postPatch = ''
    substituteInPlace ./scripts/api/ts-config.yaml \
      --replace-fail '/local' "$(pwd)"
  '';

  nativeBuildInputs = with pkgs; [
    nodejs
    openapi-generator-cli
    # nixpkgs's `typescript` alias moved to the TS 7 (tsc-go) compiler,
    # which rejects this schema's tsconfig (baseUrl). Pin the JS compiler.
    typescript_5
  ];

  buildPhase = ''
    runHook preBuild

    openapi-generator-cli generate \
      -i ./schema.yml -o $out \
      -g typescript-fetch \
      -c ./scripts/api/ts-config.yaml \
      --additional-properties=npmVersion=${sources.version} \
      --git-repo-id authentik --git-user-id goauthentik

    cd $out
    npm run build

    runHook postBuild
  '';
}
