agent-ws 0.11.0: liveness watchdog for Remote Control zombies — an exec probe
(`agent-ws-health`) restarts the agent container when no claude process holds
an established TCP connection, catching the survived-a-WAN-blip-but-never-
reconnected failure mode from the 2026-08-01 outage.
