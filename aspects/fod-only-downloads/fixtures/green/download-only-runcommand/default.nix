# Green fixture: a runCommand FOD that only downloads — curl to a file, then
# extract. No downloaded code executes.
{ pkgs ? import <nixpkgs> { } }:

pkgs.runCommand "vendor" {
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  outputHashMode = "recursive";
} ''
  curl -sSLo vendor.tar.gz https://example.com/vendor.tar.gz
  tar -xzf vendor.tar.gz -C /
''
