{ pkgs }:
pkgs.fetchgit {
  url = "ssh://forgejo@forge.ops.eblu.me:2222/eblume/%2e%2e/talos/blumeops.git";
  rev = "0123456789abcdef0123456789abcdef01234567";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
