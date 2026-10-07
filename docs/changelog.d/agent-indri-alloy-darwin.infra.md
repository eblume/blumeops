Move indri's alloy LaunchAgent and the macos-power-metrics root LaunchDaemon
to nix-darwin at the roles' labels and plist paths, key-for-key identical to
the role's renders: the unit execs the source-built CGO alloy binary (the
nixpkgs package builds with the netgo tag, which breaks Tailscale MagicDNS,
and is older, so the binary stays role-side) and the daemon the role-rendered
/usr/local/bin script; the role's gate covers only the plist + load tasks of
both units, and the daemon has no post-reboot gap (the plist is a real file
launchd re-registers at every boot; the only lost-samples window is the
rollback drill). Part of eblume/blumeops#1291.
