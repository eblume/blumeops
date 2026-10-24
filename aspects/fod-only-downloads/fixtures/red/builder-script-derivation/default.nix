# Red fixture: a derivation whose builder is a generated script — the FOD
# executes that script. A FOD's builder must be null or a fetcher primitive.
{ pkgs ? import <nixpkgs> { } }:

derivation {
  builder = pkgs.writeText "build.sh" "npm run build";
  fixedOutput = true;
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
}
