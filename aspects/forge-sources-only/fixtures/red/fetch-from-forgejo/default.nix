{ pkgs }:
{
  a = pkgs.fetchFromForgejo {
    domain = "forge.ops.eblu.me";
    owner = "talos";
    repo = "x";
    rev = "0123456789abcdef0123456789abcdef01234567";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  b = pkgs.fetchFromGitea {
    domain = "forge.ops.eblu.me";
    owner = "talos";
    repo = "x";
    rev = "0123456789abcdef0123456789abcdef01234567";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
}
