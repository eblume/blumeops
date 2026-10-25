# Red fixture (f): a drv whose nativeBuildInputs includes a setup-hook drv
# outside the allowed hook universe (the setup-hook rule).
#
# The shape is a valid fetchurl-family FOD (no phases, empty hook-inheriting
# attrs), so the template match passes; the hand-written hook in
# nativeBuildInputs (added post-hoc: fetchurl rejects unknown args) is not a
# hook of the stdenv family, of any known-shape template, nor of any normal
# derivation of the walk, so the hook rule rejects the FOD: the hook's script
# would execute inside the fixed-output build.
let
  pkgs = import <nixpkgs> { };
  foreign-hook = pkgs.makeSetupHook { name = "fodcheck-foreign-hook"; } (
    pkgs.writeText "fodcheck-foreign-hook.sh" ''
      echo "hook from outside the known nixpkgs hook universe"
    ''
  );
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  nativeBuildInputs = [ foreign-hook ];
})
