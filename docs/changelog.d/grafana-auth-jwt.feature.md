Grafana gains `[auth.jwt]` for the `agents-m2m` machine identity
(heph 01KXREAB, second half): JWKS-verified tokens as `agent-ringtail` get
Viewer via the `agents-sa` groups claim, `X-JWT-Assertion` header,
auto-provisioned on first call. Gives agents a post-deploy observability
read path (agent-health follows).
