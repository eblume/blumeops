tailscale-operator + tailscale + tailscale-k8s-nameserver bumped v1.98.5 →
v1.102.5 (service review [eblume/blumeops#1386](https://forge.eblu.me/eblume/blumeops/issues/1386)). Release
analysis found no breaking changes: additive PeerRelay CRD + RBAC, no
config/CRD migrations, image names unchanged. The window carries security
fixes TS-2026-004/005/006/007/008/009/011 and the large-tailnet container
resilience fix in 1.102.5.
