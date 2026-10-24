# Red: depsBuildBuild is a real nixpkgs dep attr stdenv sources setup hooks
# from (the cross-compile family) - an unresolvable element is a violation,
# not just the nativeBuildInputs family of names.
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo ok
  '';
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
  depsBuildBuild = [ evilHook ];
}
