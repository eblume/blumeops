{ pkgs }:
pkgs.fetchgit {
  url = "forgejo@forge.ops.eblu.me:talos/x";
  rev = "0123456789abcdef0123456789abcdef01234567";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
