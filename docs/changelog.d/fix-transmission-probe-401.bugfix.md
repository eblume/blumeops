The transmission blackbox probe now expects 401 (RPC auth is required as of
PR #661) — clearing the ServiceProbeFailure alert the auth rollout tripped,
and doubling as an alert if auth is ever accidentally disabled.
