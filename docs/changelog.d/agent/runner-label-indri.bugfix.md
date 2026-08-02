Fixed `mise run services-check`'s "Local services on indri" leg to `ssh
erichblume@indri` instead of bare `ssh indri` — the bare form relies on a
local-username mapping that only exists on gilbert, so it fails with
`tailscale: failed to look up local user` when run from ringtail (indri's
account is `erichblume`, not the caller's username).
