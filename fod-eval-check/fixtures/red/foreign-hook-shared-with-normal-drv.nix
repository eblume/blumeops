# Red fixture (F3-bypass): a FOD referencing a planted hook that ALSO appears
# in a normal (non-FOD) derivation's nativeBuildInputs of the same closure.
#
# Mechanism pinned: the review #2 hook rule DROPPED the old walk-wide
# universe clause — a hook referenced by any non-FOD derivation was part of
# the allowed universe, so planting `evil-hook = makeSetupHook` and adding it
# to an ordinary package's nativeBuildInputs legitimised the FOD's use. The
# shipped rule's universe is template-side reachable only (the stdenv-family /
# template derivations of the context's template sources) — the normal
# `fodcheck-normal-drv` is neither, so `evil-hook` stays outside the universe
# and the FOD is red. (`src = fod` threads the FOD into the same walk so the
# fixture harness sees both drvs.)
let
  pkgs = import <nixpkgs> { };
  evil-hook = pkgs.makeSetupHook { name = "fodcheck-shared-evil-hook"; } (
    pkgs.writeText "fodcheck-shared-evil-hook.sh" ''
      echo "hook planted in a normal derivation too"
    ''
  );
  fod = (pkgs.fetchurl {
    url = "https://example.com/";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  }).overrideAttrs (o: {
    nativeBuildInputs = [ evil-hook ];
  });
in
pkgs.stdenv.mkDerivation {
  pname = "fodcheck-normal-drv";
  version = "0";
  src = fod;
  nativeBuildInputs = [ evil-hook ];
}
