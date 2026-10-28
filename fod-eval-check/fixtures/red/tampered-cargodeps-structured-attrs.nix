# Red fixture: a cargo vendor-staging-shaped FOD under __structuredAttrs
# whose buildPhase is tampered to execute fetched content (`bash $out`).
# The marker is read from structuredAttrs (as phase_attrs() does), so the
# drv is recognised as cargoDeps and fails the whole-drv template match.
let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  pname = "fodcheck-red-cargodeps-structured-attrs";
  version = "0";
  __structuredAttrs = true;
  outputHashMode = "recursive";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    fetch-cargo-vendor-util create-vendor-staging ./Cargo.lock "$out"
    bash $out
  '';
  installPhase = "true";
}
