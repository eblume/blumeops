{
  # nixpkgs pin for the container builds under containers/.
  # The Build Container workflow resolves <nixpkgs> from containers/flake.lock
  # (docs/how-to/deployment/build-container-image.md). Upgrades are deliberate:
  # `nix flake update nixpkgs` here, reviewed as a blumeops PR — never automatic.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: { };
}
