# Generate Go API client bindings from authentik's OpenAPI schema
# Uses openapi-generator-cli to produce Go code from schema.yml
{ pkgs ? import <nixpkgs> { }, sources ? import ./sources.nix { inherit pkgs; } }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "authentik-client-go";
  version = "3.${sources.version}";
  inherit (sources) meta;

  src = sources.client-go-src;

  # Docker volume path /local → local pwd
  postPatch = ''
    substituteInPlace ./config.yaml \
      --replace-fail '/local' "$(pwd)"
  '';

  nativeBuildInputs = with pkgs; [
    openapi-generator-cli
    go
  ];

  buildPhase = ''
    runHook preBuild

    openapi-generator-cli generate \
      -i ${sources.src}/schema.yml -o $out \
      -g go \
      -c ./config.yaml

    gofmt -w $out

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cp go.mod go.sum $out

    cd $out
    rm -rf test
    rm -f .travis.yml git_push.sh

    runHook postInstall
  '';
}
