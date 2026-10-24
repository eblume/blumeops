let
  pkgs = import <nixpkgs> { };
in
pkgs.fetchurl {
url = "https://example.com/";
sha256 = "0000000000000000000000000000000000000000000000000000";
}

