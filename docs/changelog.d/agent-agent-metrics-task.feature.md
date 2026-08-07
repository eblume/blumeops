`mise run agent-metrics '<promql>'` — ask Prometheus a question from anywhere,
without cluster access. Goes through Grafana's datasource proxy as the same
`agents-m2m` Viewer identity `agent-health` uses, so an agent can now verify a
fix with data instead of inference: the frigate liveness-probe fix turned out
to be a measurable 26x reduction in restarts (5.72/day → 0.22/day), which
closed a task that had been open on "verify this held" since June.
