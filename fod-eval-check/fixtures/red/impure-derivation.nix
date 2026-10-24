let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
pname = "fodcheck-red-impure";
version = "0";
__impure = true;
buildCommand = "mkdir -p $out";
}

