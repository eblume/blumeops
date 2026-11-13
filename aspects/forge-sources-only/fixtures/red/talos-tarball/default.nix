{ pkgs }:
pkgs.fetchurl {
  url = "https://forge.ops.eblu.me/talos/some-tool/archive/v1.0.0.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
