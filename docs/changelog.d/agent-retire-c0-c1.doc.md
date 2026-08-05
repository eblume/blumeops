Retire the C0/C1/C2 change classification from the docs, matching AGENTS.md,
which replaced it with a two-route split: direct to main for small interactive
fixes, feature branch + PR for everything else and all remote-agent work.
`C2(<chain>):` survives as the Mikado commit-message convention. The
`change-classifier` subagent, whose only job was the retired triage, is removed.
