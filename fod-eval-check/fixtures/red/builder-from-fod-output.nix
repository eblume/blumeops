# Red fixture (round-3, D1): a derivation whose BUILDER is the output of a
# fetchurl FOD — a downloaded binary used as another FOD's interpreter.
#
# Mechanism pinned: round-3 D1 replaced strict builder equality with the
# producing-derivation rule: a store-path builder is acceptable iff its
# producing derivation is in the walk and is a NON-FOD (its outputs are path
# outputs), or the builder is the Nix builtin. Here the outer FOD's builder
# (`…-example.com`, the output of the inner fetchurl) IS produced by a
# fixed-output derivation — a downloaded binary that would execute as another
# FOD's interpreter — so the check rejects it with the D1 line
# "builder is a downloaded derivation": downloaded code executing inside a
# FOD. (The inner fetchurl itself is a genuine fetchurl shape and passes.)
#
# NB: `builtins.derivation` (not `stdenv.mkDerivation`) so the `builder` attr
# lands verbatim on the drv: this nixpkgs rev's make-derivation consumes a
# store-path `builder` argument into `args[2]` (builder stays the stdenv
# bash), which would defang the fixture — do not "simplify" it back.
let
  pkgs = import <nixpkgs> { };
in
builtins.derivation {
  name = "uses-downloaded-builder";
  system = builtins.currentSystem;
  builder = (pkgs.fetchurl {
    url = "https://example.com/";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  }).out;
  args = [ ];
  outputHashMode = "recursive";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
