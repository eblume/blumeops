`eblume-heph-spoke` moved from a system unit to a systemd **user** service
(with linger): as a system service hephd bound the `~/.local/share` fallback
socket while interactive shells looked in `/run/user/1000`, so the `heph` CLI
could never reach the daemon. Shared install machinery split into
`mkInstallUnits` (heph-common.nix).
