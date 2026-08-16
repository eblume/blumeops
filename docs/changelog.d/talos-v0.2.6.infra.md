talos image v0.2.5 → v0.2.6: pin upstream talos `81011bb` (eblume/talos#6 —
sessions now start with the `agents` repo's `AGENTS.md` preloaded into the
system prompt via pi's `agentsFilesOverride`, restoring the base context
agent-ws sessions got from waking up inside the `agents` checkout).
`npmDepsHash` unchanged (lockfile untouched); `srcHash` recomputed in-pod
with the eval-only nix (`git archive` + `nix hash path`).
