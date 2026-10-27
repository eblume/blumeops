{ pkgs }:
pkgs.fetchgit {
  url = "https://forge.ops.eblu.me/mirrors/prometheus.git";
  rev = "v3.13.0";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
