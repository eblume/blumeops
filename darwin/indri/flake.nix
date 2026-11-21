{
  description = "indri: nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # heph hub (eblume/blumeops#1655): pinned to main commit 0127458, because
    # heph capture and the voice-capture watcher (eblume/hephaestus#185) are not
    # in a release yet. Move back to a release tag once one carries them.
    # Follows this flake's nixpkgs so it compiles with aarch64-darwin's rustc.
    hephaestus = {
      url = "git+https://forge.ops.eblu.me/eblume/hephaestus.git?rev=0127458365613f067f9494943a2947958b6428ca";
      inputs.nixpkgs.follows = "nixpkgs";
      # hephaestus's rust-overlay is only for its devShells; blumeops takes packages.<system>.cli.
      inputs.rust-overlay.follows = "";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, hephaestus, ... }:
    {
      darwinConfigurations.indri = nix-darwin.lib.darwinSystem {
        # The heph store package the mcquack.eblume.heph agent's wrapper execs
        # (eblume/blumeops#1655).
        specialArgs = {
          hephPkg = hephaestus.packages."aarch64-darwin".cli;
          hephSrc = hephaestus;
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
