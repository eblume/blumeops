Fixed homepage container EACCES on cold start: the nix-built image now chowns
`/app/config` to uid 1000 at build time via `fakeRootCommands`, matching the
behavior of the old Dockerfile. Without this, homepage couldn't seed missing
skeleton configs (proxmox.yaml etc.) or create `/app/config/logs`, crashing on
its first uncached request. Caught during the ringtail cutover.
