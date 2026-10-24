# Red: a phase value reached through a dotted reference (cfg.script) is no
# more gradable than a let-bound name - the string it holds may be shell.
let
  cfg = {
    script = "make all";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = cfg.script;
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
}
