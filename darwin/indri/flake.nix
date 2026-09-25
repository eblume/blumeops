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

      # Caddy the mcquack.eblume.caddy unit runs: nixpkgs caddy built with
      # the two plugins the Caddyfile actually uses (gandi = ACME DNS-01,
      # l4 = the TCP routes). The vendor hash TOFU'd in a pod build at
      # this same nixpkgs rev (the vendored go module output is
      # platform-independent); indri's CI confirms it.
      packages."aarch64-darwin".caddy =
        nixpkgs.legacyPackages."aarch64-darwin".caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/gandi@v1.1.0"
            "github.com/mholt/caddy-l4@v0.1.2"
          ];
          hash = "sha256-aEoxvsD7aYwZdORc3iLO7TQ9vzj3bpKWqJ8eIBD/bzY=";
        };
    };
}
