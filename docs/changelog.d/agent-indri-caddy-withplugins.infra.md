indri's caddy binary moves to a nixpkgs `caddy.withPlugins` build (Gandi
DNS + L4) in the generation's closure; the role-rendered wrapper execs it
via the system profile's `sw/bin`, the plist is unchanged, and the
xcaddy checkout stays on disk as the rollback target. Part of
eblume/blumeops#1275.
