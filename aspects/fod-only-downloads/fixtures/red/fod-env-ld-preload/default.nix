# Red: LD_PRELOAD loads a shared object into the allowlisted commands it
# is exported before (here, the go that `go mod download` runs) - it is
# not an allowlisted FOD environment variable.
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    export GOTOOLCHAIN=local
    export LD_PRELOAD=$PWD/vendor/x.so
    go mod download
  '';
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000000000000000=";
}
