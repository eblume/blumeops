Move indri's four *-metrics LaunchAgents (borgmatic, forgejo, jellyfin, zot
— units + collector scripts) to nix-darwin under the same labels and plist
paths; the ansible roles now skip deployment by default and serve only the
rollback re-write, while the API key files stay controller-side op
placement. Part of eblume/blumeops#1125.
