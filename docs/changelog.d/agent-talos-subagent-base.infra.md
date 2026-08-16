talos pod: wire the base pi subagent assets into `~/.pi/agent/` at pod
start — symlink `agents` and `extensions` from the agents repo's new `pi/`
directory (pool checkout stays the source of truth), ship a `pi` CLI wrapper
at `~/.pi/agent/bin/pi`, and export `PI_BIN` for the extension's child
processes. This is what lets talos sessions delegate bounded work to cheaper
models (eblume/agents#13, eblume/talos#8). Image bumped to v0.2.9, pinning
talos main at 65d9727 (includes the subagent tools allowlist). Toolchain
gains `diffutils`, `gawk` and `hostname`.
