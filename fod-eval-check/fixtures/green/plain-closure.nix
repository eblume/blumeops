let
  pkgs = import <nixpkgs> { };
in
pkgs.runCommand "fodcheck-plain" { } "mkdir -p $out"

