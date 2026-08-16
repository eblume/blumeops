talos image v0.2.6 → v0.2.7: pin upstream talos `cde7f25` (eblume/talos#7 —
per-session git worktree isolation: each session works in its own
`~/sessions/<id>/` worktrees of the pool repos instead of sharing the pool
checkouts; a startup reaper prunes stale sessions with agent-ws semantics).
`npmDepsHash` unchanged (lockfile untouched); `srcHash` recomputed in-pod
(`git archive` + `nix hash path`).
