{ pkgs }:
pkgs.fetchgit {
  url = "https://evil.example?@forge.ops.eblu.me/eblume/x.git";
  rev = "0123456789abcdef0123456789abcdef01234567";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
