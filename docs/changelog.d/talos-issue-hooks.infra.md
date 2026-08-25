`mise run agent-repo-access` now reconciles the forge→talos webhook onto
every pool repo in repos.json alongside the collaborator grants: all 11 pool
repos get the full trigger set (`issue_assign`, `issue_label`,
`issue_comment`, plus the PR-review events), with stale hooks removed when a
repo leaves the pool. `issue_label` is new fleet-wide — groundwork for
label-driven issue engagement, since Forgejo's assignee dropdown refuses the
read-only `agents` collaborator (the API allows it; the UI does not). Also
documents the Forgejo hook-API asymmetry: writes take `pull_request_review`,
reads report the expanded `pull_request_review_*` trio — sending read-names
silently drops the review events.
