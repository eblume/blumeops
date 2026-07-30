Ringtail's heph spoke is now a **desktop** spoke: `heph-tui` (agenda/triage) and
`heph-quickadd` (quick capture) install alongside `heph`/`hephd`, and sway binds
**Alt+'** to the quick-capture popover from anywhere. The agent's headless spoke
still installs only the daemon and CLI. Shims in eblume's home-manager profile
put all four on the session `PATH` — `~/.cargo/bin` is on none of it, so until
now no heph binary (including the `heph` CLI) was reachable from a terminal
opened under sway. Because `heph-quickadd` is a
cargo-built GUI, `heph-common.nix` now also carries the graphics/input libraries
it `dlopen`s at runtime, and the install unit no longer skips a rebuild just
because `hephd` is already at the pinned tag — it also requires every requested
binary to be present.

Also installs `tea` on ringtail: `tea pr create` is the documented way to open
PRs here, but it was never on this host, so sessions running on ringtail had to
fall back to raw Forgejo API calls.
