# Red: a `++` operand that is not a literal list - its setup hooks cannot be
# graded, so the whole dep attr is not gradable.
let
  extra = [ pkgs.nodejs ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo ok
  '';
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  nativeBuildInputs = [ pkgs.gnutar ] ++ extra;
}
