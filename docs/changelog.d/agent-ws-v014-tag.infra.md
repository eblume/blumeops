Deploy agent-ws v0.14.0 — each Remote Control session gets its own worktree of
every pooled repo, and the pool tracks canonical `main`.

Built from f6b3274 (the merge of #499) as request #12, run 720. Tag confirmed
present in the registry rather than derived from the naming convention —
`container-list` reports no tags from inside the pod, since it has no route to
`registry.ops.eblu.me`.

First boot on this image does three things the previous one did not: seeds the
`SessionStart` hook into `~/.claude/settings.json`, fast-forwards each pool
checkout onto canonical `main` (including pushing the bot's fork `main` up to
match), and reaps the fourteen session worktrees that have accumulated on the
PVC since 2026-07-31 — skipping any that are dirty or hold a commit canonical
`main` lacks.
