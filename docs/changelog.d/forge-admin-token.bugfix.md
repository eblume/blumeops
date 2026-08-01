The agent-repo-access CI secret is `FORGE_ADMIN_TOKEN`, not
`FORGEJO_ADMIN_TOKEN`. Forgejo reserves the `FORGEJO_` prefix for the Actions
tokens it injects itself and rejects creating a secret that uses it, so
`provision-indri --tags forgejo_actions_secrets` failed with HTTP 400 on that one
entry while the other five synced fine. The `cv` repo's `FORGE_TOKEN` was already
the same workaround; the reason is now recorded in the role defaults so the name
doesn't get "corrected" back.
