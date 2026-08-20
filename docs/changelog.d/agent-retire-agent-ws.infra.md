Retire agent-ws. Remove the agent-ws image (containers/agent-ws), its k8s
manifests and ArgoCD app, its service-versions entry, and the claude-login
rotation runbook; talos supersedes it. The shared tag:agent Tailscale auth key
is renamed to generic agent naming (Pulumi `agent_authkey`, 1Password item
'agent Tailscale Auth Key', `mise run agent-authkey-sync`).
