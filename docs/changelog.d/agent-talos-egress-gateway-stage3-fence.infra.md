Flip the talos agent pod's egress fence to deny-by-default (eblume/talos#69
stage 3). The pod's legal egress is now exactly: the egress-gateway pod
(all real egress transits it, session-tagged logs), cluster DNS (kube-dns,
53 UDP+TCP — the pod resolves direct clients itself), and authentik (9000
TCP, the in-cluster OIDC issuer fetch exempted from the proxy by no_proxy).
Merging this PR is the cutover — egress becomes mandatory at the kernel —
and it belongs in a human change window; recovery is a single `git revert`.
