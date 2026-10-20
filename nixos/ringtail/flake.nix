{
  description = "NixOS configuration for ringtail (service host & gaming PC)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Pinned nixpkgs for versioned services (forgejo-runner, k3s, kubectl).
    # Update this deliberately during service reviews, not via
    # `nix flake update`.
    # Current versions: forgejo-runner 13.2.0, k3s 1.35.8+k3s1, kubectl 1.36.3.
    nixpkgs-services.url = "github:NixOS/nixpkgs/7c8764b7c7b09b34f632464276218ef9090eaa11";

    # snowflake-proxy pinned on nixpkgs-unstable separately from
    # nixpkgs-services (eblume/blumeops#1702) so advancing it does not
    # co-move k3s and kubectl. Fold back onto nixpkgs-services at
    # nixos-26.11.
    nixpkgs-snowflake.url = "github:NixOS/nixpkgs/2e42b2892d964b175c84c125e3ace59644ea88a1";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # heph for both ringtail spokes (agent + eblume desktop): the release flake builds one package with all
    # four bins (eblume/hephaestus#98), pinned to the release tag; the explicit
    # rev is that tag's commit. Follows this flake's nixpkgs so it compiles
    # with ringtail's rustc 1.95.0 (heph's floor, exactly); a floor bump that
    # outruns the 26.05 branch gets a rust-overlay/fenix input pinned here,
    # not a second toolchain path.
    hephaestus = {
      url = "git+https://forge.ops.eblu.me/eblume/hephaestus.git?ref=v1.10.7&rev=1d8c478e41fd64ee4a3ee109d20849a102cd229f";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-services, nixpkgs-snowflake, disko, home-manager, hephaestus, ... }: {
    nixosConfigurations.ringtail = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # The heph store package (both spokes' hephd, the session shims, and the myeve sync consume it as `hephPkg`).
      specialArgs = {
        hephPkg = hephaestus.packages.x86_64-linux.heph;
      };
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./disk-config.nix
        ./hardware-configuration.nix
        ./configuration.nix
        ./gaming.nix
        # Pin versioned services instead of the rolling nixpkgs: snowflake via
        # the dedicated nixpkgs-snowflake input, forgejo-runner/k3s/kubectl via
        # nixpkgs-services. This prevents `nix flake update nixpkgs` from
        # silently upgrading them. The inputs are frozen — bump explicitly
        # during service reviews.
        ({ ... }: {
          nixpkgs.overlays = [
            (final: prev: let
              svcPkgs = nixpkgs-services.legacyPackages.x86_64-linux;
              snowPkgs = nixpkgs-snowflake.legacyPackages.x86_64-linux;
            in {
              forgejo-runner = svcPkgs.forgejo-runner;
              snowflake = snowPkgs.snowflake;
              k3s = svcPkgs.k3s;
              kubectl = svcPkgs.kubectl;
            })
          ];
        })
      ];
    };
  };
}
