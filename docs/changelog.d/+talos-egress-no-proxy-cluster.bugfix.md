Exempt cluster-internal destinations from the talos pod's egress proxy
(`no_proxy=.cluster.local,…`): the stage-2 cutover routed the server's OIDC
discovery fetch (TALOS_OIDC_INTERNAL_URL, authentik in-cluster service) into
the egress gateway, which rightly blocked the private destination — the
server crash-looped at startup. In-cluster service traffic is not egress;
the stage-3 fence needs a matching egress rule (eblume/talos#69).
