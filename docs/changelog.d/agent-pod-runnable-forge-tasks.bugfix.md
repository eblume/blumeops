`runner-logs` works from an agent pod: it now targets the public forge host
instead of the tailnet name plain httpx cannot reach, prefers the `upstream`
remote over a fork's `origin` when detecting the repo, and bounds its `op read`
with `stdin=DEVNULL`, a timeout, and a clean error instead of hanging. Dropped
the `[human]` tag it should never have carried — AGENTS.md points agents at
this task for exactly the job it could not do.

`container-list` no longer reports every container as untagged when the
registry is unreachable; it says so and exits non-zero, and can be routed
through the pod's SOCKS sidecar with `ALL_PROXY`.
