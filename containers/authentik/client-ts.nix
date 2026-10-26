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
    pkgs.nodejs
    openapi-generator-cli
    # nixpkgs's `typescript` is now the Go port (tsc-go), which removed the
    # `baseUrl` tsconfig option (TS5102) that the generated config emits.
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
    # tsc-go removed the `baseUrl` option (TS5102); the generator emits
    # `"baseUrl": "."`, a no-op under NodeNext resolution, so drop the line.
    grep -v '"baseUrl"' tsconfig.json > .tsconfig.tmp && mv .tsconfig.tmp tsconfig.json
    npm run build

    runHook postBuild
  '';
}
