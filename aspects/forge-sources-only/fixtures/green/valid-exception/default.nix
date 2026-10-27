{ pkgs }:
pkgs.fetchurl {
  url = "https://dl.grafana.com/oss/release/grafana-11.0.0.linux-amd64.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
