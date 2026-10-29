# Generate TypeScript fetch client bindings from authentik's OpenAPI schema
# Uses openapi-generator-cli to produce TypeScript code, then compiles with tsc
{ pkgs ? import <nixpkgs> { }
, sources ? import ./sources.nix { inherit pkgs; }
, openapi-generator-cli ? import ./openapi-generator-cli.nix { inherit pkgs; }
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "authentik-client-ts";
  inherit (sources) version src meta;

  # Docker volume path /local → local pwd
  postPatch = ''
    substituteInPlace ./packages/client-ts/config.yaml \
      --replace-fail '/local/templates' "$(pwd)/packages/client-ts/templates"
  '';

  nativeBuildInputs = [
    pkgs.nodejs_26
    openapi-generator-cli
    pkgs.typescript
  ];

  buildPhase = ''
    runHook preBuild

    openapi-generator-cli generate \
      -i ./schema.yml -o $out \
      -g typescript-fetch \
      -c ./packages/client-ts/config.yaml \
      --additional-properties=npmVersion=${sources.version} \
      --git-repo-id authentik --git-user-id goauthentik

    cd $out
    # The generator emits `"baseUrl": "."`, a no-op under NodeNext resolution.
    grep -v '"baseUrl"' tsconfig.json > .tsconfig.tmp && mv .tsconfig.tmp tsconfig.json
    # Upstream's build script runs `pnpm run clean` first; skipped here since $out is fresh.
    tsc -b tsconfig.json tsconfig.esm.json

    runHook postBuild
  '';
}
