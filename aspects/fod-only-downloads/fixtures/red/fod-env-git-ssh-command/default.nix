# Red: GIT_SSH_COMMAND makes the git that `go mod download` spawns run a
# command - it is not an allowlisted FOD environment variable.
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    export GOTOOLCHAIN=local
    export GIT_SSH_COMMAND=./x
    go mod download
  '';
  outputHash = "sha256-00000000000000000000000000000000000000000000000000000000000000000=";
}
