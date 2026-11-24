{
  description = "indri: nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # heph hub (eblume/blumeops#1655): pinned to main commit 272863f, because
    # heph capture and the voice-capture watcher (eblume/hephaestus#185) are not
    # in a release yet. Move back to a release tag once one carries them.
    # Follows this flake's nixpkgs so it compiles with aarch64-darwin's rustc.
    hephaestus = {
      url = "git+https://forge.ops.eblu.me/eblume/hephaestus.git?rev=ed3ea926fffccf830001141d7bc6ca6a01b85b91";
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
          caddyPkg = self.packages."aarch64-darwin".caddy;
        };
        modules = [ ./configuration.nix ];
      };

      # The forgejo-runner the generation's unit runs, exposed so indri's
      # workflows-validate CI builds the exact same binary (same pinned
      # nixpkgs rev) instead of a checkout on disk.
      packages."aarch64-darwin".forgejo-runner =
        nixpkgs.legacyPackages."aarch64-darwin".forgejo-runner;

      # Caddy the mcquack.eblume.caddy unit runs, and the one configuration.nix
      # takes via specialArgs, so the deployed binary and the CI build are one
      # derivation. The locked nixos-26.05 caddy is overridden to the latest
      # upstream release (2.11.9; src and vendor hashes as nixos-unstable builds
      # it). The plugins are the two the Caddyfile uses (gandi = ACME DNS-01,
      # l4 = the TCP routes); the plugin vendor hash is pinned from indri's CI build.
      packages."aarch64-darwin".caddy =
        let
          pkgs = nixpkgs.legacyPackages."aarch64-darwin";
          caddy = pkgs.caddy.overrideAttrs {
            version = "2.11.9";
            # fetchzip on the archive URL, not fetchFromGitHub: forge-sources-only
            # grades fetches by URL and rejects fetchFromGitHub outright.
            src = pkgs.fetchzip {
              url = "https://github.com/caddyserver/caddy/archive/refs/tags/v2.11.9.tar.gz";
              hash = "sha256-K7irjePU998bcbKANXpTf0npirSh+tkc8D3x4JmRdbg=";
            };
            vendorHash = "sha256-qjLumZHCyoM+lNZtWOTmMlHN5zgB36fv9CkIq3ncMlM=";
          };
          # This nixpkgs's withPlugins is bound to the unoverridden caddy, so call its
          # plugin builder on the override.
          withPlugins = pkgs.callPackage (pkgs.path + "/pkgs/by-name/ca/caddy/plugins.nix") { inherit caddy; };
        in
        withPlugins {
          plugins = [
            "github.com/caddy-dns/gandi@v1.2.1"
            "github.com/mholt/caddy-l4@v0.1.3"
          ];
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
    };
}
