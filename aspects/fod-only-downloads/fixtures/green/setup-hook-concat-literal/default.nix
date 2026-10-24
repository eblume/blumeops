# Green: a `++` chain of literal lists - every operand is a graded literal
# list of plain nixpkgs references, so it is green.
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo ok
  '';
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  nativeBuildInputs = [ pkgs.gnutar ] ++ [ pkgs.cacert ];
}
