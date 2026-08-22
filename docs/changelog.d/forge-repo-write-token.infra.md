CI no longer holds the eblume admin PAT: `agent-repo-access` and
`warrant-bot-drift` now use `FORGE_REPO_WRITE_TOKEN`, a `write:repository,read:user`-scoped
eblume PAT (1Password `forge-repo-write-token`), replacing `FORGE_ADMIN_TOKEN`.
Empirical test showed collaborator management and branch-protection reads need
repo-admin *permission* (which eblume has as owner) but only the repository
token *scope* — the old "write:repository 403s" note was wrong, and is retired
from the workflow and script comments.
