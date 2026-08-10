`github-mirror-pat` is now `forge-ci-github-pat`. Mirroring is one consumer of
that credential, not the only one — it is indri's general-purpose credential for
reading public GitHub, and CI tool resolution is the next consumer lined up, to
stop mise 401ing when it resolves a tool from the GitHub API.

Renaming rather than minting a second token, because the capability is already
right: it is a fine-grained PAT with **no permissions**, granting read-only
access to public repositories and nothing else. A second token with identical
reach would buy only another 20-day rotation chore. The rotation runbook grows a
note to keep it scopeless, which matters more once CI jobs can read it.

`mise-tasks/mirror-update-pats` keeps its name. It updates the PAT on mirror
repos, which is still exactly what it does.

**This requires a matching 1Password field rename, and the two must be
sequenced.** Add the new field to the Forgejo Secrets item with the same value
first, leaving the old one in place; merge this; then delete the old field. Both
consumers (`mirror-create`, `mirror-update-pats`) are `[human]` tasks that only
run around a rotation, so the window is forgiving — but additive-then-remove
leaves no window at all.
