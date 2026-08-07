---
title: Rotate the agent-ws Claude OAuth Login
modified: 2026-08-07
last-reviewed: 2026-08-07
tags:
  - how-to
  - ringtail
  - ai
---

# Rotate the agent-ws Claude OAuth Login

Re-run the interactive `claude auth login` inside the [[agent-workspaces]]
pod. This is a **recurring 5-day chore** ("Rotate agent-ws Claude OAuth
login", Blumeops project in heph), not break-glass: the login's refresh token
hard-expires ~7 days after login and Claude Code refresh tokens are
single-use, so concurrent sessions can burn it even sooner
([claude-code#24317](https://github.com/anthropics/claude-code/issues/24317)).
The 5-day cadence leaves ~2 days of buffer.

There is no non-interactive alternative: Remote Control refuses `claude
setup-token` / `CLAUDE_CODE_OAUTH_TOKEN` credentials as inference-only (see
[[agent-workspaces#Authentication]] — v0.16.0 tried it and crash-looped). A
human at a browser is required, by Anthropic's design.

Expiry is currently **silent** — the pod stays green while every session
start fails (`agent-ws-health` only checks for an ESTABLISHED TCP
connection). If you're here because sessions are failing with `OAuth session
expired and could not be refreshed`, this same procedure is the fix.

## 1. Log in inside the pod

Needs a real TTY (`-it`) and the full path. From gilbert the default kubectl
context is right; **from ringtail add `--context k3s-ringtail`** (the default
context there points at a retired cluster).

```fish
kubectl exec -it -n agent-ws deploy/agent-ws -c agent -- \
    /home/agent/.local/bin/claude auth login
```

Open the printed URL in your own browser, approve, and paste the code back.
This overwrites `~/.claude/.credentials.json` on the PVC — the new ~7-day
clock starts now.

## 2. Verify

```fish
kubectl exec -n agent-ws deploy/agent-ws -c agent -- \
    /home/agent/.local/bin/claude auth status
```

Then confirm end-to-end from the Claude app: the `ringtail-agent` environment
should accept a **new** session. The running remote-control process picks up
the credential file at session start, so a pod restart is normally not
needed; if a new session still fails, restart cleanly and re-check:

```fish
kubectl delete pod -n agent-ws -l app=agent-ws
```

(A restart is cheap: the PVC and the tailscale sidecar identity survive, and
the startup probe allows ~20 min for the entrypoint to come back.)

## 3. Close the chore

```fish
heph list --project Blumeops --json --due   # find the rotation task's node_id
heph done <node_id>                         # recurring — rolls forward 5 days
```

## Related

- [[agent-workspaces]] — §Authentication for why only this credential works
- [[bootstrap-agent-workspaces]] — first-time seeding (consent + trust flags)
