`warrant-bot-provision`: user creation needs `write:admin`, which the stored
forge token deliberately lacks. Adds `--token` for an ephemeral admin token
(never stored), mints the bot's PAT **as the bot** over basic auth (no admin
scope for that step), and prints the exact remediation on 403.
