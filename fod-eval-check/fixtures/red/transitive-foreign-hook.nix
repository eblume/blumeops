# Red fixture (F3-transitive): a FOD whose hook chains to a planted foreign
# hook through another hook-providing driver.
#
# Mechanism pinned: the effective hooks of a FOD are the TRANSITIVE closure
# of hook-providing derivations linked through hook-providing drvs (review #2,
# F3): the FOD references `hook-p` directly, and `hook-p` itself references a
# second hook-providing derivation `hook-q` through its inputs. Both must be in
# the template-side hook universe. Neither is (both are planted here, and no
# template references them), so the FOD is red with a violation per hook —
# including `hook-q`, which a direct-inputs-only rule would have missed.
let
  pkgs = import <nixpkgs> { };
  hook-q = pkgs.makeSetupHook { name = "fodcheck-transitive-hook-q"; } (
    pkgs.writeText "fodcheck-hook-q.sh" ''
      echo "transitive planted hook q"
    ''
  );
  hook-p = pkgs.makeSetupHook {
    name = "fodcheck-transitive-hook-p";
    # the hook-to-hook link: another hook-providing drv as a dependency
    propagatedNativeBuildInputs = [ hook-q ];
  } (
    pkgs.writeText "fodcheck-hook-p.sh" ''
      echo "planted hook p"
    ''
  );
in
(pkgs.fetchurl {
  url = "https://example.com/";
  sha256 = "0000000000000000000000000000000000000000000000000000";
}).overrideAttrs (o: {
  nativeBuildInputs = [ hook-p ];
})
