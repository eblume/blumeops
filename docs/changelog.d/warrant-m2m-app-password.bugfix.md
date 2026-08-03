authentik m2m round 2: the client_credentials flow authenticates a specific
service account via username + **app password** (issuing the token as
`agent-ringtail`, groups claim included); the bare client_secret-only
variant hits the app's `agents-sa` policy binding as a foreign auto-SA →
`invalid_grant`. Adds a vault-fed app-password token to the blueprint.
