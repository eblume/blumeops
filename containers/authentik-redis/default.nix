# Nix-built Redis for Authentik
# Attached service: cache/broker (sessions, Celery task queue, caching)
# Uses Redis from nixpkgs, packaged with dockerTools.buildLayeredImage
#
# The containers pin (nixos-26.05) only carries Redis 8.8.x, so this overrides
# redis alone to the latest 8.x release. Drop the override once the pin
# carries that version.
#
# The version assertion ensures nix-build fails if a flake.lock update
# changes the Redis version — forcing an explicit version acknowledgment
# here and in service-versions.yaml (enforced by container-version-check).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "8.10.3";

  redis = pkgs.redis.overrideAttrs (old: {
    inherit version;
    src = pkgs.fetchgit {
      url = "https://forge.ops.eblu.me/mirrors/redis.git";
      rev = version;
      hash = "sha256-ftzedXSe3QwEe3ZWaLJTpeO1PY2OP++7SuurJjY4OyM=";
    };
    # Same patch nixpkgs carries for 8.10 (redis/redis#15585).
    patches = [
      (pkgs.fetchpatch2 {
        url = "https://forge.ops.eblu.me/mirrors/redis/commit/c027c8effe13564bcbc903741305acd929cc23da.patch";
        hash = "sha256-7FudmjysFLY14aDmbSM+KlboBSZeg/npmlYug9HI1iA=";
      })
    ] ++ old.patches;
    # The 26.05 checkPhase skip-list is tuned for 8.8; nixpkgs unstable runs
    # the 8.10 suite as a separate passthru instead.
    doCheck = false;
  });
in

# Guards the pin's own redis: a flake.lock bump that moves it forces a look at this override.
assert pkgs.redis.version == "8.8.2";

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/authentik-redis";
  contents = [
    redis
  ];

  config = {
    Entrypoint = [ "${redis}/bin/redis-server" ];
    Cmd = [ "--protected-mode" "no" ];
    ExposedPorts = {
      "6379/tcp" = { };
    };
    # Run as uid 1000 per the PSA non-root decision (docs/reference/operations/security.md).
    User = "1000";
  };
}
