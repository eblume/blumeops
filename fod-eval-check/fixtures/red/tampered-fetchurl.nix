# Red fixture (e): a fetchurl-shape drv with a tampered buildPhase.
#
# The fetcher shapes carry no phases (all phase handling is stdenv-defaulted
# download-only behaviour); a buildPhase attribute on a fetchurl (added here
# post-hoc, since fetchurl rejects unknown args at eval) is shell executed
# inside the FOD build.
let
  pkgs = import <nixpkgs> { };
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  buildPhase = ''
    echo "tampered fetchurl"
  '';
})
