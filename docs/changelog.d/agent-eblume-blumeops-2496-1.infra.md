`provision-indri` no longer needs Docker on gilbert: the flake.lock check runs locally only where nix is present, and on indri (read-only, before the switch) otherwise.
