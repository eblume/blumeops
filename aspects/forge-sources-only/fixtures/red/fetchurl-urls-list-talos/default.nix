{ pkgs }:
pkgs.fetchurl {
  urls = [ "https://forge.ops.eblu.me/talos/x/archive/v1.tar.gz" ];
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
