{ pkgs }:
pkgs.fetchurl {
  url = "https://github.com/grafana/beyla/releases/download/v2.0.0/beyla-linux-amd64-v2.0.0.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
