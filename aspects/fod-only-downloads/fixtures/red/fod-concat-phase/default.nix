# Red: a phase string built by concatenation is not gradable inline.
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo start
  '' + ''
    make all
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
