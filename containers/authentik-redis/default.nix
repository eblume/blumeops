# Nix-built Redis for Authentik
# Attached service: cache/broker (sessions, Celery task queue, caching)
# Uses Redis from nixpkgs, packaged with dockerTools.buildLayeredImage
#
# The version assertion ensures nix-build fails if a flake.lock update
# changes the Redis version — forcing an explicit version acknowledgment
# here and in service-versions.yaml (enforced by container-version-check).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "8.2.3";
in

assert pkgs.redis.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/authentik-redis";
  contents = [
    pkgs.redis
  ];

  config = {
    Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    Cmd = [ "--protected-mode" "no" ];
    ExposedPorts = {
      "6379/tcp" = { };
    };
  };
}
