Move indri's four borgmatic LaunchAgents (main, ops, photos, verify-photos)
to nix-darwin at the roles' labels and plist paths, with the units execing
the mise pipx `latest` borgmatic binary — the main unit runs both archive-tier
configs (config.yaml + talos-data.yaml) — while configs, keys, dump helpers
and the mise install stay role-rendered and the role's gate covers only the
plist + load tasks. Part of eblume/blumeops#1291.
