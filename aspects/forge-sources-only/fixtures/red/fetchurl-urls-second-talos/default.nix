{ pkgs }:
pkgs.fetchurl {
  urls = [ "https://forge.ops.eblu.me/eblume/ok/archive/v1.tar.gz" "https://forge.ops.eblu.me/talos/bad/archive/v1.tar.gz" ];
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
