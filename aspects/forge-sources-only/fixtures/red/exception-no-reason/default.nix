{ pkgs }:
pkgs.fetchurl {
  url = "https://dl.example.org/tool.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
