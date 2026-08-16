talos image v0.2.8 → v0.2.9: subagent base assets wired into the pod
(#575 — `agents/pi` symlinked into `~/.pi/agent/`, `pi` CLI wrapper,
`PI_BIN` exported) and the pod's nix upgraded from eval-only to real
builds (#579 — canonical `/nix/store` chowned to the container user,
`cache.nixos.org` substitution, `max-jobs = 2`, ephemeral-storage cap).
Toolchain gains `diffutils`, `gawk`, `hostname`. Talos source pinned at
`65d9727` (includes eblume/talos#8, the subagent tools allowlist);
`npmDepsHash` unchanged, `srcHash` recomputed in-pod.
