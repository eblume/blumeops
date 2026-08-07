Recover seven changelog fragments that towncrier would have dropped. Branch
names containing a slash produced `docs/changelog.d/agent/*.md`, and towncrier
skips subdirectories without a word, so entries from PRs #439, #440, #521,
#522, #523 and #524 were headed for a release that never mentioned them.
`mise run changelog-check` had anticipated exactly this failure since it was
written and was wired into nothing; the new **Docs Checks** workflow now runs
it, plus the frontmatter and wiki-link validators, on every PR.
