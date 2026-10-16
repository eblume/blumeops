{
  description = "indri: nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # heph hub (eblume/blumeops#1655): the `cli` output (heph + hephd, no
    # heph-quickadd GUI stack) pinned to the release tag; the explicit rev is
    # that tag's commit. Follows this flake's nixpkgs so it compiles with
    # aarch64-darwin's rustc. Same pin shape as nixos/ringtail's spokes'
    # input; the hub and the spokes bump independently.
    hephaestus = {
      url = "git+https://forge.ops.eblu.me/eblume/hephaestus.git?ref=v1.10.9&rev=7227cbe22b25fa36190d9ca9b6940e2828c1dc17";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, hephaestus, ... }:
    {
      darwinConfigurations.indri = nix-darwin.lib.darwinSystem {
        # The heph store package the mcquack.eblume.heph agent's wrapper execs
        # (eblume/blumeops#1655).
        specialArgs = {
          hephPkg = hephaestus.packages."aarch64-darwin".cli;
        };
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
