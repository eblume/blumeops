{ pkgs }:
pkgs.fetchgit {
  url = "forgejo@forge.ops.eblu.me:eblume/blumeops.git";
  rev = "0123456789abcdef0123456789abcdef01234567";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
