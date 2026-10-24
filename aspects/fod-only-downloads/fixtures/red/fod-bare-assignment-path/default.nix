# Red: a bare (non-exported) assignment still reaches child processes -
# the build environment already exports PATH, so the git that
# `go mod download` spawns comes from $PWD/bin. PATH is not an allowlisted
# FOD environment variable, however it is set.
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    PATH=$PWD/bin:$PATH
    export GOTOOLCHAIN=local
    go mod download
  '';
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
}
