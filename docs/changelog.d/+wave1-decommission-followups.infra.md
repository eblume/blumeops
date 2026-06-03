Fix three follow-ups from the wave-1 decommission: grant the local
break-glass `admin` account ArgoCD admin rights (`g, admin, role:admin` —
previously only the Authentik `admins` group had access, so admin was
locked out whenever its token expired), and repoint the alloy blackbox
probe for teslamate from the deleted minikube service to
`https://tesla.ops.eblu.me/` (through Caddy over Tailscale). The orphaned
paperless/teslamate roles + ExternalSecrets left on the minikube
blumeops-pg are also cleaned up.
