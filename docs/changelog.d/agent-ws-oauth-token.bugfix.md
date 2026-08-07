agent-ws now authenticates to Anthropic with a long-lived `claude setup-token`
credential read from `op://agents/claude-oauth-token/token`, instead of the
interactive OAuth login stored on the PVC. That login's refresh token carried a
hard ~7-day expiry and died silently — remote-control kept reporting
`✔︎ Connected` and the liveness probe stayed green while every session start
failed `OAuth session expired and could not be refreshed`. Auth now survives PVC
loss and rotates without a shell in the pod.
