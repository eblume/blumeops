# Nix-built Valkey for ringtail (amd64)
# Companion to container.py (Alpine 3.22, arm64 on indri).
# Used by immich-ringtail which needs an amd64 image; paperless on indri
# continues to use the Alpine container.py build.
#
# The version assertion ensures nix-build fails if a flake.lock update
# changes the Valkey version — forcing an explicit version acknowledgment
# here and in service-versions.yaml (enforced by container-version-check).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "8.1.7";
in

assert pkgs.valkey.version == version;

pkgs.dockerTools.buildLayeredImage {
  name = "blumeops/valkey";
  contents = [
    pkgs.valkey
  ];

  config = {
    Entrypoint = [ "${pkgs.valkey}/bin/valkey-server" ];
    Cmd = [ "--bind" "0.0.0.0" "--protected-mode" "no" "--dir" "/data" ];
    ExposedPorts = {
      "6379/tcp" = { };
    };
  };
}
