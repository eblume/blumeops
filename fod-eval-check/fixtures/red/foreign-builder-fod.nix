# Red fixture (round-3, D1): a FOD whose builder is a foreign NON-bash store
# binary (`writeScript` output) on an otherwise unrecognised (non-fetchurl)
# FOD shape.
#
# Mechanism pinned: round-3 D1 admits ANY builder whose producing derivation
# is in the walk and non-FOD (the writeScript drv is a normal derivation), so
# the builder itself is NOT what reds this fixture — what reds it is the FOD
# SHAPE: the derivation carries no family key set (no `urls`/fetcher keys),
# matches no nixpkgs-native template and no catalogue entry, so it is an
# `unrecognised FOD shape`. The eval check owns the downloaded surface — a
# fixed-output derivation must be an intact known fetcher shape with a
# hash-checked download; a hand-rolled shape (whatever its builder) is red.
let
  pkgs = import <nixpkgs> { };
in
let
foreign-builder = pkgs.writeScript "fodcheck-foreign-builder" ''
  #!${pkgs.stdenv.shell}
  mkdir -p $out
'';
in
pkgs.stdenv.mkDerivation {
pname = "fodcheck-red-foreign-builder";
version = "0";
builder = "${foreign-builder}";
outputHashMode = "recursive";
outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
