let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
pname = "fodcheck-red-custom-buildphase";
version = "0";
outputHashMode = "recursive";
outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
buildPhase = ''
  echo "arbitrary code in a FOD"
'';
installPhase = "mkdir -p $out";
}

