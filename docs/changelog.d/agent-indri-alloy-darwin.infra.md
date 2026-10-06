Move indri's alloy LaunchAgent and the macos-power-metrics root LaunchDaemon
to nix-darwin at the roles' labels and plist paths, key-for-key identical to
the role's renders: the unit execs the source-built CGO alloy binary (the
nixpkgs bottle is CGO-disabled and older, so the binary stays role-side) and
the daemon the role-rendered /usr/local/bin script; the role's gate covers
only the plist + load tasks of both units, and a post-reboot daemon gap costs
only lost power samples until the next switch. Part of eblume/blumeops#1291.
