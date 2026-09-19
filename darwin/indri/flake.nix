{
  description = "indri: nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, ... }:
    {
      darwinConfigurations.indri = nix-darwin.lib.darwinSystem {
        modules = [ ./configuration.nix ];
      };

      # The forgejo-runner the generation's unit runs, exposed so indri's
      # workflows-validate CI builds the exact same binary (same pinned
      # nixpkgs rev) instead of a checkout on disk.
      packages."aarch64-darwin".forgejo-runner =
        nixpkgs.legacyPackages."aarch64-darwin".forgejo-runner;
    };
}
