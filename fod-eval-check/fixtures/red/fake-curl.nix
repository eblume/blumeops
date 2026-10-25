# Red fixture: a fetchurl FOD whose nativeBuildInputs shadow the fetcher curl.
# The canonical fetchurl template's nativeBuildInputs is the nixpkgs curl dev
# output; this instance replaces it with a repo-defined fake curl bin dir,
# which the build environment puts on PATH — the fake curl runs instead of
# the real fetcher curl inside the fixed-output build. nativeBuildInputs must
# be compared strictly to the template, or the check accepts this FOD.
let
  pkgs = import <nixpkgs> { };
  fake-curl = pkgs.writeShellScriptBin "curl" ''
    echo "fake curl"
  '';
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  nativeBuildInputs = [ fake-curl ];
})
