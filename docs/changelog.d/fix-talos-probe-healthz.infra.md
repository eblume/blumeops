Repointed the talos pod's liveness/readiness probes from `:3000/auth/login`
(redirects — a ProbeWarning on every check — and renders a page) to the
dedicated `:9464/healthz`, and raised the probe timeout from the 1s default
to 5s. Under 5+ concurrent sessions the single Bun event loop couldn't answer
within 1s for 90s and the kubelet liveness-killed the pod, ending every
session at once (2026-08-31).
