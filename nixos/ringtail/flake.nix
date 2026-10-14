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

    # heph for the agent spoke: the release flake builds one package with all
    # four bins (eblume/hephaestus#98), pinned to the release tag. `rev` is the
    # tag's commit — nix can't fetch a Forgejo ref by tag name. Follows this
    # flake's nixpkgs so it compiles with ringtail's rustc 1.95.0 (heph's
    # floor, exactly); a floor bump that outruns the 26.05 branch gets a
    # rust-overlay/fenix input pinned here, not a second toolchain path
    # (eblume/blumeops#1541).
    hephaestus = {
      url = "git+https://forge.ops.eblu.me/eblume/hephaestus.git?ref=v1.10.7&rev=1d8c478e41fd64ee4a3ee109d20849a102cd229f";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-services, disko, home-manager, hephaestus, ... }: {
    nixosConfigurations.ringtail = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # The agent spoke's hephd comes from the store (agent-heph-spoke.nix
      # picks it up as the `hephPkg` special arg), not a cargo-install oneshot:
      # the package is in the toplevel, so the spoke starts at boot like any
      # other service.
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
        # Pin versioned services to nixpkgs-services instead of the rolling nixpkgs.
        # This prevents `nix flake update nixpkgs` from silently upgrading them.
        # Bump nixpkgs-services explicitly during service reviews.
        ({ ... }: {
          nixpkgs.overlays = [
            (final: prev: let svcPkgs = nixpkgs-services.legacyPackages.x86_64-linux; in {
              forgejo-runner = svcPkgs.forgejo-runner;
              snowflake = svcPkgs.snowflake;
              k3s = svcPkgs.k3s;
              kubectl = svcPkgs.kubectl;
            })
          ];
        })
      ];
    };
  };
}
