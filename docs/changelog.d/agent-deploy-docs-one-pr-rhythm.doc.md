Deployment docs describe the sync policy the fleet actually has. AGENTS.md
called ArgoCD "manual sync" and prescribed `app set --revision main && app
sync` after every merge; 31 of 35 applications sync themselves, so that step
raced the auto-sync the merge had already started. `deploy-k8s-service`'s
Application template also omitted `automated`, quietly making each new service
a manual-sync exception.
