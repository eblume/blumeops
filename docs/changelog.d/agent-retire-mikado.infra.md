Remove the Mikado apparatus: the `mikado-branch-invariant-check` commit-msg
hook, the `docs-mikado` viewer, the `mikado-navigator` subagent, and the
`C2(<chain>):` commit convention. No chain was using it — canonical carried no
`mikado/*` branch and no card with Mikado frontmatter. Multi-phase work is now
just a branch and a PR.
