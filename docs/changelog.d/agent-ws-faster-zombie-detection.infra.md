agent-ws: cut zombie-detection latency from ~10min to ~3min by moving boot
grace into a `startupProbe` (up to 20min for cold-PVC boots) and tightening
the `agent-ws-health` livenessProbe to 30s × 6 failures. The 2026-08-06
incident confirmed the detector fires correctly, but the old window was long
enough that the workspace read as "offline" in the Claude app before kubelet
recycled it.
