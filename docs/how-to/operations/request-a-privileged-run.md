---
title: Request a Privileged Run
modified: 2026-08-02
last-reviewed: 2026-08-02
tags:
  - how-to
  - operations
  - ai
---

# Request a Privileged Run

How an agent (or a human at a keyboard without deploy rights) formally asks
for a privileged workflow dispatch, and how the human approves it. This is
Phase 1 of [[warrant-approval-gated-runs]].

## Request

```fish
mise run request-run <workflow> <full-sha> [--pr N] [-i key=value]... [--why TEXT] [--notify]
```

Example — request a container build at a merged commit:

```fish
mise run request-run build-container.yaml 892eeacbca29ee5e64fb6dae90ccc64a77ee69b7 \
    --pr 440 -i container=mealie -i ref=892eeacbca29ee5e64fb6dae90ccc64a77ee69b7 \
    --why "post-squash-merge rebuild for the #440 mealie bump"
```

What it does:

- validates the SHA is full-length and the workflow exists **on `main`**
  (privileged definitions execute from main only — invariant 3);
- resolves the PR (auto-detected when the SHA is an open PR's head; `--pr`
  for post-merge or unusual cases) and posts a structured **request comment**
  there: workflow, SHA, inputs, justification, diff + dispatch links;
- warns loudly in the comment if the PR touches `.forgejo/workflows/**`;
- files an attention-orange **heph task** (`Approve: <workflow> @ <sha7>`) —
  the system of record for pending approvals. An unactioned request is a
  visible orange task, not a lost chat message;
- with `--notify`, additionally pushes to ntfy topic `ops-approvals`
  (optional by design — see the notification-channel analysis in
  [[warrant-approval-gated-runs]]).

The tool holds no privileged credentials and cannot trigger anything: it
authenticates as the [[agents-forgejo-bot]] (`write:issue`), which is
read-only on canonical and cannot dispatch. The request *grants* nothing.

## Approve (human)

1. Open the request comment; review the **diff at the requested SHA**.
2. Open the dispatch page link → *Run workflow* → paste the SHA and inputs
   from the request → run. (Forge login is the auth factor — keep WebAuthn
   enrolled on the account.)
3. Verify the run (`mise run runner-logs`), then `heph done` the tracking
   task with a short log of the outcome.

To **deny**: reply on the request comment, then `heph done` the task with the
reason.

## Rules of the road

- Approvals bind to the **full SHA** in the request — if the branch moved,
  ask for a fresh request rather than dispatching the new tip.
- Dispatch privileged workflows **from `main`'s definition** only.
- Never paste secret values into requests, comments, or heph — requests
  reference *actions*, and secrets stay in the execution context.

## Related

- [[warrant-approval-gated-runs]] — the design this implements
- [[agents-forgejo-bot]] — the requesting identity and its fences
- [[build-container-image]] — the most common privileged run
