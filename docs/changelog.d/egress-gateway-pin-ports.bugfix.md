Pin `EGRESS_FORWARD_PORT`/`EGRESS_CONNECT_PORT` explicitly on the egress-gateway
Deployment: v0.4.43's env plumbing lets unset vars clobber the code defaults
with `undefined`, so the freshly deployed gateway 403'd every CONNECT/forward
(`443 !== undefined`). Explicit values restore egress and make the allowed-port
contract auditable in the manifest; the code fix lands in talos separately.
