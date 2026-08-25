`agent-repo-access` now reconciles the `agents` engagement label onto every
pool repo (create-if-missing), alongside the collaborator grant and the talos
webhook. The label is the only UI path for engaging talos on issues in the
read-only repos (the assignee dropdown excludes read-only collaborators), and
it only existed on blumeops — which is why `horkos#4` never spawned a session
despite a fully working webhook. Label API calls need Forgejo's issue scope,
which the narrow CI PAT lacks, so the label half falls back to the
blumeops-vault api-token locally and skips with a loud warning in CI.
