`mise run agent-health` — fleet health via Grafana alert-rule states, run
as the `agent-ringtail` machine identity (agents-vault creds only, Viewer
access, SOCKS fallback for the pod). Exit 0/2/1 for inactive/pending/
firing — the agent-usable replacement for services-check's kubectl/ssh
legs (heph 01KZ2XGW).
