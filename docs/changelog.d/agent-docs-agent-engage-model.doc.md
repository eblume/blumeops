The agents-forgejo-bot docs now describe the post-#725 issue-engagement
model instead of the stale "apply the `agents` label" one: an issue opened
by an allowlisted creator (Erich, or the bot for cron-filed briefs) starts a
cycle on its own, the `agents` label is the secondary engagement edge (and
the only UI path on the read-only repos), assignment works only where the
bot has write, and a human comment re-triggers an engaged or allowlisted-created issue. Updated
`docs/reference/infrastructure/agents-forgejo-bot.md` and the
`agent-repo-access` module docstring, which also carried a stale pinned
read-only repo count ("two" → the actual four).
