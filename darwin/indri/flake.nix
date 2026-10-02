{
  description = "indri: nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # colima (container runtimes on macOS) is the build runner's engine host
    # (eblume/blumeops#1357): it is not in the pinned nixpkgs, so it is pinned
    # here at the latest stable release. Owned by abiosoft (lima's author) -
    # the repo is `abiosoft/colima`, not `sail-sg/colima`. Its flake exposes
    # packages.default, which wraps colima with lima and qemu into its PATH
    # (there is no separate lima output to follow).
    colima = {
      type = "github";
      owner = "abiosoft";
      repo = "colima";
      ref = "v0.10.3";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, ... }:
    {
      darwinConfigurations.indri = nix-darwin.lib.darwinSystem {
        modules = [ ./configuration.nix ];
        # Module files receive the flake's inputs (nix-darwin shim), so
        # configuration.nix can reference `inputs.colima` for the build
        # runner's daemon binary.
        inputs = inputs;
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
