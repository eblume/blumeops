Move indri's caddy LaunchAgent (unit) to nix-darwin under the same
label and plist path; the xcaddy-built binary stays at ~/code/3rd/caddy
and the Caddyfile / wrapper / Gandi token file stay ansible-rendered, so
the ansible role's gate now covers only the plist + load tasks
(rollback re-write). Part of eblume/blumeops#1125.
