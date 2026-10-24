# Red: buildInputs is a dep attr stdenv sources setup hooks from - an
# unresolvable element is a violation, not just nativeBuildInputs.
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo ok
  '';
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  buildInputs = [ evilHook ];
}
