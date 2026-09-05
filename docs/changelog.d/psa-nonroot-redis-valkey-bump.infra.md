Bump authentik-redis 8.6.3 → 8.8.2 and valkey 8.1.7 → 9.1.1 to match the
nix-container-builder's current nixpkgs. Two of the five PSA non-root
rebuilds (#797, pinned by #872) failed on the `default.nix` version
assertions because nixpkgs had moved since the versions were last declared;
mealie, paperless and teslamate built fine. immich upstream pins valkey 9,
and both valkey consumers use emptyDir, so the major bump carries no data
migration.
