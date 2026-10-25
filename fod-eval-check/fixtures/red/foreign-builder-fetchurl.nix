# Red fixture: a template-identical fetchurl FOD with a foreign non-FOD
# builder. Every env/args attr equals the canonical fetchurl template except
# the builder, which is a repo-written script produced by a normal derivation.
# The foreign builder executes inside the fixed-output build; a builder that
# is not the template's (or the Nix builtin) must be rejected whatever its
# producing derivation, or the check accepts this FOD. (Spliced into the raw
# derivation attrs — this rev's make-derivation would eat a store-path
# `builder` into args[2]; args stay untouched and inputs.srcs is unchanged.)
let
  pkgs = import <nixpkgs> { };
  base = pkgs.fetchurl {
    url = "https://example.com/";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };
  foreign-builder = pkgs.writeScript "fodcheck-foreign-builder" ''
    #!${pkgs.stdenv.shell}
    mkdir -p $out
  '';
in
builtins.derivation (base.drvAttrs // {
  builder = "${foreign-builder}/bin/fodcheck-foreign-builder";
})
