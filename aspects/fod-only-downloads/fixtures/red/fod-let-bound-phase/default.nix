# Red: a phase string assembled in a let binding is not gradable inline.
let
  buildCmd = ''
    make all
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = buildCmd;
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
