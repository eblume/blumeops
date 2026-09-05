# Nix-built Valkey for ringtail (amd64)
# Used by immich-ringtail and paperless-ringtail (both pin this image in
# their kustomizations).
#
# The version assertion ensures nix-build fails if a flake.lock update
# changes the Valkey version — forcing an explicit version acknowledgment
# here and in service-versions.yaml (enforced by container-version-check).
{ pkgs ? import <nixpkgs> { } }:

let
  version = "9.1.1";
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
    # Run as uid 1000 per the PSA non-root decision (docs/reference/operations/security.md).
    User = "1000";
  };
}
