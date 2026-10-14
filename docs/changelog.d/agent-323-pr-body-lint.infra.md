Extract the PR-body after-merge check from docs-checks.yaml into the standalone
`pr-body-lint` mise task, which the workflow now calls: agents can run the exact
Docs Checks check locally before posting a PR body (`./mise-tasks/pr-body-lint`
or `mise run pr-body-lint`), and its pytest table of must-match/must-pass
headings is mirrored in the talos `tea` wrapper so pattern drift fails as a
test instead of a silent difference. Part of eblume/talos#323.
