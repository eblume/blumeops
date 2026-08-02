Authentik gains the agent identity tier ([[warrant-approval-gated-runs]] P3
prereq, heph 01KXREAB): `agents-sa` group, `agent-ringtail` service account,
and an `agents-m2m` client-credentials OAuth2 provider whose client secret is
vault-fed (`Authentik (blumeops)` → `agents-m2m-client-secret`), so consumers
read the same value from the agents vault.
