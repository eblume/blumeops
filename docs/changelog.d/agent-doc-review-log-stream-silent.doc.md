Reviewed the Log Stream Silent runbook (never reviewed) against the alert
rules, the alloy role, and live Prometheus metrics. Everything checked out
except the `zot.err` "known exception" paragraph: the broken tail is fixed
(positions wedge cleared, alloy's `loki.process` guard drops the Trivy
progress-bar lines over 255KB) and the referenced heph audit task is done —
the paragraph now states the current guard behavior instead.
