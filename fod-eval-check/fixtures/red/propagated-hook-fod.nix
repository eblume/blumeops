# Red fixture (b): a fetchurl-shape FOD carrying a non-empty
# propagatedNativeBuildInputs (a hook-inheriting attr).
#
# The shape would otherwise match the fetchurl family template, but the
# template match requires the hook-inheriting attrs to be empty: inherited
# hooks execute inside the FOD's build. (fetchurl rejects unknown args at
# eval, so the attrs are added post-hoc via overrideAttrs.)
let
  pkgs = import <nixpkgs> { };
  evil-hook = pkgs.makeSetupHook { name = "fodcheck-evil-hook"; } (
    pkgs.writeText "fodcheck-evil-hook.sh" ''
      echo "executing inside a FOD"
    ''
  );
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  propagatedNativeBuildInputs = [ evil-hook ];
})
