---
title: Request a Privileged Run
modified: 2026-08-20
last-reviewed: 2026-08-20
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
mise run request-run <workflow> <full-sha> [--pr N] [--repo owner/name] [-i key=value]... \
    [--why TEXT] [--supersedes ID] [--notify]
```

Example — request a container build at a merged commit:

```fish
mise run request-run build-container.yaml 892eeacbca29ee5e64fb6dae90ccc64a77ee69b7 \
    --pr 440 -i container=mealie -i ref=892eeacbca29ee5e64fb6dae90ccc64a77ee69b7 \
    --why "post-squash-merge rebuild for the #440 mealie bump"
```

Example — clear the orphan ConfigMaps holding an app `OutOfSync`. `prune` is the
one input that **deletes live resources**, so say what you expect it to remove:

```fish
mise run request-run argocd-deploy.yaml <full-sha> --pr N \
    -i app=grafana-ringtail -i revision=<full-sha> -i prune=true \
    --why "clear the superseded grafana-* ConfigMap orphaned by the last configMapGenerator edit"
```

The run logs an `argocd app sync --prune --dry-run` preview before it prunes, so
the run record names exactly what went. `prune=true` requires `sync=true` (the
prune is an option on the sync) and the workflow refuses the combination rather
than reporting green having pruned nothing. See [[argocd#Sync Policy]] for why
orphans accumulate in the first place.

Example — the attached PR lives in another repo. A change in `eblume/talos`
that needs the talos image rebuilt is bound to a *blumeops* commit (the
definition lives here), but the review the approver wants to read is the
talos PR:

```fish
mise run request-run build-container.yaml <full-blumeops-sha> \
    --pr 12 --repo eblume/talos -i container=talos -i ref=<full-blumeops-sha> \
    --why "rebuild the talos image for the eblume/talos change"
```

`--repo` moves only the attachment: the request comment, the heph task title,
and Warrant's queue and approve page all name `eblume/talos` PR #12 instead of
blumeops PR #12, which would be a different change entirely. The workflow
validation, the bound SHA, and the dispatch stay blumeops.

What it does:

- validates the SHA is full-length and the workflow exists **on `main`**
  (privileged definitions execute from main only — invariant 3);
- resolves the PR (auto-detected when the SHA is an open PR's head; `--pr`
  for post-merge or unusual cases; `--repo owner/name` when the PR lives in
  another repo) and posts a structured **request comment** there: workflow,
  SHA, inputs, justification, diff + dispatch links;
- warns loudly in the comment if the PR touches `.forgejo/workflows/**`;
- files an attention-orange **heph task** (`Approve: <workflow> @ <sha7>
  (PR #N)` — with the repo named for non-blumeops PRs) — the system of record
  for pending approvals. An unactioned request is a
  visible orange task, not a lost chat message;
- **mirrors the request into [[warrant]]** (`warrant.ops.eblu.me`) with the
  agents-m2m identity — best-effort in v0.1 (the PR comment + heph task stay
  the system of record; a broker failure warns and moves on);
- with `--notify`, additionally pushes to ntfy topic `ops-approvals`
  (optional by design — see the notification-channel analysis in
  [[warrant-approval-gated-runs]]).

The tool holds no privileged credentials and cannot trigger anything: it
authenticates as the [[agents-forgejo-bot]] (`write:issue`), which is
read-only on canonical and cannot dispatch. The request *grants* nothing.

## When the PR moves

A request is bound to one commit, so review feedback kills it: push a fix and
the request that was filed against the old head can no longer be approved into
anything useful. File the replacement and retire the old one in one step:

```fish
mise run request-run build-container.yaml <new-full-sha> \
    --pr 525 -i container=talos -i ref=<new-full-sha> \
    --supersedes 21 --why "rebuild after review feedback"
```

`--supersedes` marks request 21 `superseded` in Warrant (it stops being
approvable), notes the supersession on its PR comment, and closes its heph
tracking task. Without it, both requests sit in the queue looking live and the
approver has to work out which is which.

It only ever *reduces*: Warrant scopes the call to your own still-pending
requests, so it cannot retire someone else's request or undo a decision a
human already made. If the retirement fails, the new request is still filed
and the old one is still pending — the comment says so.

## Approve (human)

Approvals happen in [[warrant]] — https://warrant.ops.eblu.me:

1. Sign in (Authentik; MFA applies) and find the request.
2. **Read the change**: the row links the PR, its diff, and the commit.
3. `approve…` → the confirm page shows the full input set and states the
   effect → approve. Warrant mints a single-use warrant and dispatches the
   workflow as `warrant-bot`; the run is linked on the warrant.
4. **deny** is inline on the row (with a note). Deny anything already
   executed — the queue records intent, not history.

`mise run verify-runs` then closes the tracking task from the run's outcome.

**Fallback** (Warrant disarmed or down): dispatch from the forge UI using the
SHA and inputs in the request comment — the request stays the record either
way.

## Policy

Requests are validated against **`warrant-policy.yaml` on `main`** — the
reviewed agent-autonomy boundary ([[warrant-approval-gated-runs]] Phase 4).
Unknown actions are deny-by-default; each action declares its input schema
(required keys, patterns, existence validators), so typos fail at request
time, not run time. Making a new workflow requestable = adding its policy
entry in the same PR that adds the workflow.

## Rules of the road

- Approvals bind to the **full SHA** in the request — if the branch moved,
  file a fresh request (`--supersedes` the old one) rather than dispatching
  the new tip.
- Dispatch privileged workflows **from `main`'s definition** only.
- Never paste secret values into requests, comments, or heph — requests
  reference *actions*, and secrets stay in the execution context.

## Related

- [[warrant-approval-gated-runs]] — the design this implements
- [[agents-forgejo-bot]] — the requesting identity and its fences
- [[build-container-image]] — the most common privileged run
