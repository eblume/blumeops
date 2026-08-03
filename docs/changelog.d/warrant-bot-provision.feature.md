`mise run warrant-bot-provision` — scripted, human-run ceremony for the
Warrant dispatch identity: creates the `warrant-bot` forge user, grants
write on blumeops, mints a `write:repository` PAT, and stores it in
`blumeops-ci`. Deliberately not a workflow — minting privileged
credentials from CI would need vault-write in CI and would turn
FORGE_ADMIN_TOKEN into an escalation path.
