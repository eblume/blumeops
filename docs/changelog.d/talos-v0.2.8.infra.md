talos image v0.2.7 → v0.2.8: pin upstream talos `3995a5a` (eblume/talos#9 —
fix: sessions whose working directory is a per-session worktree vanished from
the sidebar, because the session list filtered on the shared pool path;
the filter now matches on the session's own worktree).
`npmDepsHash` unchanged (lockfile untouched); `srcHash` recomputed in-pod
(`git archive` + `nix hash path`) and verified with a real `fetchgit` eval.
