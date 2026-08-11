The four local prek hooks — `container-version-check`, `changelog-check`,
`docs-check-links`, `docs-check-frontmatter` — now run their script directly
instead of through `mise run`, which installed the whole `[tools]` block first
and made the Lint job depend on the GitHub API it has no credential for.
