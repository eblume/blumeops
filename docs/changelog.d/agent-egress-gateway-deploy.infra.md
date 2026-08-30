Deploy the talos egress gateway pod (egress-gateway Deployment + fixed-IP
Service + talos-pods-only ingress NetworkPolicy) and pin the talos image to
v0.4.43-da8d73d-nix (folds the v0.4.43 pin bump from #743). Stage 1 of the
egress-gateway rollout (eblume/talos#69): the gateway holds the tag:agent
Tailscale identity; the agent pod cutover and the deny-by-default fence
flip follow as separate PRs.
