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
pod. This is a **recurring 21-day chore** ("Rotate agent-ws Claude OAuth
login", Blumeops project in heph), not break-glass: the login's refresh token
expires ~29 days after login, and Claude Code refresh tokens are single-use,
so concurrent sessions can burn it even sooner
([claude-code#24317](https://github.com/anthropics/claude-code/issues/24317)).
The 21-day cadence leaves ~8 days of buffer for that.

> **The ~29 days is measured, not documented.** A login on 2026-08-07T18:01Z
> wrote `refreshTokenExpiresAt` of 2026-09-05T19:54Z. Anthropic publishes no
> figure, so treat it as an observation that could change under you — which is
> why step 2 has you read the real deadline off the credential each time rather
> than trusting the cadence. (An earlier "~7 day" figure in these docs was
> wrong: it came from assuming the credential was minted when the PVC was
> created, when in fact it had been carried over from the pre-container host
> login 22 days earlier.)

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

From gilbert the printed URL is clickable and lands straight on the claude.ai
scope-approval page. Approve it, copy the code, and paste it back into the
same terminal.

> **The paste is invisible.** The code prompt is a password field, and over
> `kubectl exec` it echoes *nothing at all* — no dots, no cursor movement — so
> a successful paste looks identical to a dead terminal. It does work: press
> Cmd-V then Enter and trust it. Don't paste twice.

This overwrites `~/.claude/.credentials.json` on the PVC; the new ~29-day
clock starts now.

## 2. Verify, and read the real deadline

```fish
kubectl exec -n agent-ws deploy/agent-ws -c agent -- \
    /home/agent/.local/bin/claude auth status
```

Expect `authMethod: claude.ai` and `subscriptionType: max`. Then read the
actual expiry off the credential rather than trusting the 21-day cadence —
this is the only authoritative source, and it doubles as a check on whether
the ~29-day window still holds:

```fish
kubectl exec -n agent-ws deploy/agent-ws -c agent -- sh -c \
    'jq ".claudeAiOauth.refreshTokenExpiresAt" /home/agent/.claude/.credentials.json'
```

That's epoch milliseconds; `date -r <seconds>` on gilbert converts it. If it
lands materially sooner than ~29 days out, shorten the chore's interval.

## 3. Let the container cycle, if the credential had already expired

If you are rotating *ahead* of expiry, remote-control is running fine and
picks the new credential up at the next session start — nothing more to do.

If you are here **because** it expired, remote-control already exited at
launch (`You must be logged in to use Remote Control`) and cannot pick
anything up. The liveness probe notices within ~3 minutes and recycles the
container, which relaunches remote-control against the new credential — so
just wait a minute rather than concluding the login failed (observed
2026-08-07). To force it:

```fish
kubectl delete pod -n agent-ws -l app=agent-ws
```

Confirm it came back:

```fish
kubectl exec -n agent-ws deploy/agent-ws -c agent -- agent-ws-health   # exit 0
kubectl logs -n agent-ws deploy/agent-ws -c agent --tail=5 | grep Connected
```

Then confirm end-to-end from the Claude app: the `ringtail-agent` environment
should accept a **new** session. (A restart is cheap: the PVC and the
tailscale sidecar identity survive, and the startup probe allows ~20 min for
the entrypoint to come back.)

## 4. Close the chore

```fish
heph list --project Blumeops --json --due   # find the rotation task's node_id
heph done <node_id>                         # recurring — rolls forward 21 days
```

## Related

- [[agent-workspaces]] — §Authentication for why only this credential works
- [[bootstrap-agent-workspaces]] — first-time seeding (consent + trust flags)
