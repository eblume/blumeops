Reconcile a new `needs-proper-review` label onto every pool repo via the
`agent-repo-access` label half (create-if-missing, alongside the `agents`
and `no-agents` labels). A human uses it to flag an issue or PR that needs
a dedicated human review; talos's `pull_request_review` webhook clears it
once any review lands (eblume/talos#158).
