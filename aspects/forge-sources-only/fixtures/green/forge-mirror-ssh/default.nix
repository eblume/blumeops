{ pkgs }:
pkgs.fetchgit {
  url = "ssh://forgejo@forge.ops.eblu.me:2222/mirrors/prometheus.git";
  rev = "0123456789abcdef0123456789abcdef01234567";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
