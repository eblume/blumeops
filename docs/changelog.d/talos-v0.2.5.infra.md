Pin upstream talos 0a95bf1 (v0.2.5): markdown rendering in chat,
stop/steer agent controls, dictation-review input, and the dictation
status gutter (talos PRs #4–#5). The lockfile gained a direct `marked`
dep, so `npmDepsHash` changes with this bump. `srcHash` computed
in-pod via `builtins.fetchGit` (eval-only nix, [[agent-containerization]]).
