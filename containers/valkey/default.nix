# Nix-built Valkey for ringtail (amd64)
# Used by immich-ringtail and paperless-ringtail (both pin this image in
# their kustomizations).
#
# Self-pins nixpkgs instead of using containers/flake.lock, which lags valkey.
# The version assertion ensures nix-build fails if the pin changes the
# Valkey version — forcing an explicit version acknowledgment here and in
# service-versions.yaml (enforced by container-version-check).
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/e5cadf7bef7de5439392b000dd602d3b482c0e83.tar.gz";
    sha256 = "0p0xs7i483bbaaiid7516r45737pdm5xdnlb09gjavahqy5ziqm9";
  };
  pkgs = import nixpkgs { system = "x86_64-linux"; };

  version = "9.1.3";
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
