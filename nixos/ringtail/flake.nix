{
  description = "NixOS configuration for ringtail (service host & gaming PC)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Pinned nixpkgs for versioned services (forgejo-runner, snowflake, k3s).
    # Update this deliberately during service reviews, not via `nix flake update`.
    # Current versions: forgejo-runner 12.11.1, snowflake 2.11.0, k3s 1.34.5+k3s1
    nixpkgs-services.url = "github:NixOS/nixpkgs/3cac626ec5e3703e835f227687e88aa9e2f25701";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-services, disko, home-manager, ... }: {
    nixosConfigurations.ringtail = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./disk-config.nix
        ./hardware-configuration.nix
        ./configuration.nix
        ./gaming.nix
        # Pin versioned services to nixpkgs-services instead of the rolling nixpkgs.
        # This prevents `nix flake update nixpkgs` from silently upgrading them.
        # Bump nixpkgs-services explicitly during service reviews.
        ({ ... }: {
          nixpkgs.overlays = [
            (final: prev: let svcPkgs = nixpkgs-services.legacyPackages.x86_64-linux; in {
              forgejo-runner = svcPkgs.forgejo-runner;
              snowflake = svcPkgs.snowflake;
              k3s = svcPkgs.k3s;
            })
          ];
        })
      ];
    };
  };
}
