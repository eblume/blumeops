Each Remote Control session now gets its own worktree of every pooled repo,
and the pool itself is kept pinned to canonical `main`.

Only the `agents` repo had per-session isolation, because that is all
`claude remote-control --spawn worktree` does — it operates on its own cwd repo
and nothing else. The other seven pooled repos were one shared checkout each, so
two concurrent sessions editing blumeops contended for one HEAD and one index.
The only thing preventing that was a paragraph in the agents repo's `AGENTS.md`
telling sessions to branch first, and the evidence that it is load-bearing is
already on the PVC: two prior sessions had hand-rolled their own blumeops
worktrees, by two different methods, one detached and one on a branch.

`agent-ws-workspace` (new, generated from `repos.json` like the clone loop) has
three verbs. `init` is a `SessionStart` hook and gives the session a detached
worktree of each repo at `~/code/sessions/<session-id>/<repo>`. `sync` fetches
and fast-forwards each pool checkout onto canonical `main`. `gc` reaps the
worktrees of sessions that have ended. `sync` and `gc` also run once at pod boot.

Worktrees rather than clones: they share the object store, and they enforce
one-branch-one-checkout *in git* rather than by convention. Measured cost is
14 MB for all seven — the whole pool is 43 MB.

Three things fell out of building it that were not the original goal:

**Sessions were waking up stale.** The clone loop only fetches at pod boot, so
`--spawn worktree` branches off whatever `main` was when the pod started. On a
pod up for days that is visibly wrong in the one repo where it matters most:
this change was authored from a session whose `agents` worktree — and therefore
whose own base instructions — was two commits behind canonical. `init` now
fast-forwards the session's `agents` worktree too, when it is clean.

**A fork's `main` lies.** `origin` on `agents` and `blumeops` is the bot's fork,
so `git status` says "up to date with origin/main" while canonical is 110 commits
ahead. `sync` pushes canonical `main` onto the fork so that sentence means what
it appears to mean and cross-repo PR diffs stay honest. Fast-forward only; a
diverged fork is left alone and reported.

**Nothing ever reaped worktrees.** Fourteen had accumulated since 2026-07-31.
`gc` uses Remote Control's own worktree lock as the liveness signal, waits
`AGENT_WS_GC_AGE_DAYS` (7) after the session goes quiet, and — the part worth
reviewing — refuses to remove anything with a dirty tree or a commit canonical
`main` does not already contain, reporting it instead. Losing an agent's
unpushed work is worse than the disk. A crashed session would hold its lock
forever, so a lock older than `AGENT_WS_GC_LOCK_MAX_DAYS` (30) is treated as
dead.

The hook is seeded into **user** settings (`~/.claude/settings.json`, jq-merged,
re-written every boot) rather than committed to the agents repo as project
settings, because project-scoped hooks prompt for trust on first use and there is
nobody at a terminal in this pod. The image stays the source of truth for it,
which is also what the agents repo's own "changing your own environment is a
blumeops PR" rule asks for.

`CARGO_TARGET_DIR` is now shared across every checkout. Without it, per-session
worktrees each build Rust from cold — minutes for Bevy — and a `target/` per
worktree per session fills a 20Gi PVC quickly. Cargo locks the directory, so
concurrent builds serialize rather than corrupt each other.

Verified in the pod rather than reasoned about: the script was extracted from the
derivation and run against the real pool. `sync` is clean across all eight repos;
`init` produces seven detached worktrees at canonical `main` and is idempotent;
`gc` reaps a clean aged session and refuses an aged one carrying an unpushed
commit.

This is working-tree isolation, not a security boundary and not repository-level
isolation — refs, remotes, config, and the object store all stay shared, and all
sessions remain one process, one uid, one PVC. True per-session isolation means a
pod per session, which the RWO PVC and single rooted Remote Control server rule
out today.

Image toolchain version 0.13.0 → 0.14.0.
