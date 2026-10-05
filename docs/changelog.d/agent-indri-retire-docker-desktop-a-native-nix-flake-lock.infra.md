`provision-indri` and `provision-ringtail` run `nix flake lock` natively where nix is present, falling back to the nixos/nix container only on nixless controllers (gilbert).
