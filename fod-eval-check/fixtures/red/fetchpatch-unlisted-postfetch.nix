let
  pkgs = import <nixpkgs> { };
in
pkgs.fetchpatch {
  url = "https://example.com/f.patch";
  hash = "sha256-0000000000000000000000000000000000000000000=";
  relative = "src";
}
