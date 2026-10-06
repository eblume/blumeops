`forge-reconcile` is now the single forge drift check: it folds in the retired
`horkos-forge-drift` tool's blast-radius invariants (horkos-forge not a site
admin, write on exactly the `horkos_forge` set, blumeops `main` whitelisted to
eblume), takes over its weekly schedule, and reports same-repo PR drift as
intended (warn + PR comment, auto-applies on merge) vs unexpected (fail) —
fork/agent PRs skip.
