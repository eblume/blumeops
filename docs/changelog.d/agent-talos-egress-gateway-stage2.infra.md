Cut the talos agent pod over to the egress gateway (eblume/talos#69 stage 2):
the in-pod Tailscale sidecar is dropped (the tag:agent identity lives in the
egress-gateway pod now), EGRESS_GATEWAY_URL points at the gateway's fixed
clusterIP, and the pod runs dnsPolicy: None (the gateway resolves proxied
hostnames; the CGNAT fence in networkpolicy.yaml is untouched — the
deny-by-default flip is stage 3, its own PR).
