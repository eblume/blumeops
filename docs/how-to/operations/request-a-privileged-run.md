---
title: Request a Privileged Run
modified: 2026-09-21
last-reviewed: 2026-09-16
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
    [--why TEXT] [--supersedes ID] [--notify] [--script <file|->]
```

Example — redeploy the Fly.io proxy at a merged commit:

```fish
mise run request-run deploy-fly.yaml 892eeacbca29ee5e64fb6dae90ccc64a77ee69b7 \
    --pr 440 -i revision=892eeacbca29ee5e64fb6dae90ccc64a77ee69b7 \
    --why "deploy the #440 fly proxy change"
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

Example — sync a **tag-tracking app** (one whose Application tracks a tag on
a mirror rather than blumeops `main`, e.g. `external-secrets-crds-ringtail`).
`revision=declared` syncs the app at the revision its Application on `main`
already declares, without re-pointing it — `revision=main` would repoint the
app at the mirror's `main`, and a mirror SHA would leave the spec pinned to
a SHA. The bound SHA is the blumeops commit whose `argocd/apps/<app>.yaml`
declares the revision, and the run fails if the live Application's
`targetRevision` differs from that declaration (sync the apps root with
`argocd-sync-apps.yaml` first):

```fish
mise run request-run argocd-deploy.yaml <full-blumeops-sha> --pr N \
    -i app=external-secrets-crds-ringtail -i revision=declared \
    --why "sync the CRDs at the tag main's manifest declares"
```

Example — pick up newly added Application manifests: the one step of a
merged service deploy that agents could not run, because the pod's `argocd`
CLI is read-only. `argocd-deploy.yaml` with `app=apps` would leave the
app-of-apps root pinned at the bound SHA — it would then read `Synced`
against the pin and silently ignore every later `argocd/apps/` merge. This
action pins, syncs, waits healthy, and resets the root to tracking main, so
the next drift stays loud:

```fish
mise run request-run argocd-sync-apps.yaml <full-sha> --pr N \
    -i revision=<full-sha> --why "create the <service>-ringtail Application"
```

Example — apply a merged blumeops commit to ringtail as a NixOS rebuild. The
bound SHA is applied on ringtail by the root `ringtail-apply@<sha>` unit,
which the priv runner is allowed (by polkit) to start. On success the run log
shows the checkout plus the wrapper's log ending in a one-line verdict naming
the `/etc/blumeops` commit ringtail now runs; on failure the rebuild's journal
tail is in that log.

```fish
mise run request-run ringtail-rebuild.yaml <full-sha> -i revision=<full-sha> \
    --why "apply #NN: <what the commit changes>"
```

Example — apply a merged blumeops commit's nix-darwin generation to indri.
The bound SHA is applied by the zero-prompt rebuild path (checkout plus
detached `darwin-rebuild switch`, bounded wait) from the host-mode indri
runner; the run log ends with the system profile's store path before and
after the switch. The full provision (roles, `op read`) stays a human
window.

```fish
mise run request-run provision-indri.yaml <full-sha> -i revision=<full-sha> \
    --why "apply #NN: <what the commit changes>"
```

Example — the attached PR lives in another repo. A change in `eblume/horkos`
that ships a new horkos image lands its pin as a *blumeops* commit (the
deploy definition lives here), but the review the approver wants to read is
the horkos release PR:

```fish
mise run request-run argocd-deploy.yaml <full-blumeops-sha> \
    --pr 12 --repo eblume/horkos -i app=horkos -i revision=<full-blumeops-sha> \
    --why "deploy the horkos release"
```

`--repo` moves only the attachment: the request comment, the heph task title
(filed as `Approve: <workflow> @ <sha7> (PR #12 (eblume/horkos))`), and
Horkos's queue and approve page all name `eblume/horkos` PR #12 instead of
blumeops PR #12, which would be a different change entirely. The workflow
validation, the bound SHA, and the dispatch stay blumeops.

### One-off scripts

Instead of a named workflow, request that *a specific script* run: the body is
read from a file (or stdin with `-`), hashed, and filed as the bound pair —
the approver reads the full body on Horkos's confirm page, and the warrant
authorizes exactly one execution of exactly that body.

```fish
mise run request-run run-script.yaml <blumeops-main-sha> --pr N \
    --script ./scripts/do-the-thing.sh \
    --why "rotate the zot ci key: the run below, nothing else"
```

The bound SHA is where the executor checks out blumeops (policy and runner
assets the script may lean on) — normally the current main tip. After
approval, the run executes on the priv runner with `op` access to
`blumeops-ci`, and its full output is durable on the Horkos warrant detail
page, not only in the forge run log.

The runner also has `kubectl` for cluster chores (orphan PV/PVC teardowns).
Its credential is a bound, expiring (12-month) token of the `horkos`/
`run-script` ServiceAccount, stored as the concealed `blumeops-ci` item
`k3s-run-script` — reachable only from this warrant-gated context — with the
least-priv grant: `get`/`list`/`delete` on `persistentvolumes`, `get`/`list`
on `persistentvolumeclaims`, nothing else (no secrets at any scope, no
namespace or PVC writes). The kubeconfig's server URL is `https://127.0.0.1:6443`
(loopback), so a kubeconfig that leaks into a run log is useless as-is from any
other device. Canonical prologue for such a script:

```bash
KUBECONFIG=$(mktemp); trap 'rm -f "$KUBECONFIG"' EXIT
op read 'op://blumeops-ci/k3s-run-script/kubeconfig' > "$KUBECONFIG"; chmod 600 "$KUBECONFIG"; export KUBECONFIG
```

Reviewers reject any script that prints the file, runs `kubectl config view
--raw`, or passes `-v>=6`.

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
- **mirrors the request into [[horkos]]** (`horkos.ops.eblu.me`) with the
  agents-m2m identity — best-effort in v0.1 (the PR comment + heph task stay
  the system of record; a broker failure warns and moves on). The request is
  filed with an `origin_issue`: the attached PR's first issue reference — a
  keyword ref like `Part of #N` or `Part of owner/repo#N`, or an issue URL —
  searched in title then body, with unprefixed refs defaulting to the PR's
  repo. After the run settles, horkos posts the settlement outcome
  (success/failure/cancelled/denied/voided/dispatch_failed) as one comment on
  that issue (see eblume/horkos#40); a PR that references no issue just files
  without one.
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
mise run request-run argocd-deploy.yaml <new-full-sha> \
    --pr 525 -i app=grafana-ringtail -i revision=<new-full-sha> \
    --supersedes 21 --why "deploy after review feedback"
```

`--supersedes` marks request 21 `superseded` in Horkos (it stops being
approvable), notes the supersession on its PR comment, and closes its heph
tracking task. Without it, both requests sit in the queue looking live and the
approver has to work out which is which.

It only ever *reduces*: Horkos scopes the call to your own still-pending
requests, so it cannot retire someone else's request or undo a decision a
human already made. If the retirement fails, the new request is still filed
and the old one is still pending — the comment says so.

## Approve (human)

Approvals happen in [[horkos]] — https://horkos.ops.eblu.me:

1. Sign in (Authentik; MFA applies) and find the request.
2. **Read the change**: the row links the PR, its diff, and the commit.
3. `approve…` → the confirm page shows the full input set and states the
   effect → approve. Horkos mints a single-use warrant and dispatches the
   workflow as `horkos-forge`; the run is linked on the warrant.
4. **deny** is inline on the row (with a note). Deny anything already
   executed — the queue records intent, not history.

`mise run verify-runs` then closes the tracking task from the run's outcome —
including warrants attached to PRs in other repos, whose repo-qualified task
titles the sweep matches as well.

A request can also end **voided** instead of being decided: its bound PR
closed unmerged, or its workflow left `warrant-policy.yaml`, so its reason to
exist went away. Void is terminal — a re-request needs a fresh `request-run`
— and `verify-runs` closes the tracking task with the void reason.

**Fallback** (Horkos disarmed or down): dispatch from the forge UI using the
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
- Post-merge steps never go in the PR body: if it isn't automatic on merge,
  it's a warrant the post-merge cycle files, or a `- [ ]` item in the linked
  issue's `## Human steps` comment (AGENTS.md § Privileged actions).

## Related

- [[warrant-approval-gated-runs]] — the design this implements
- [[agents-forgejo-bot]] — the requesting identity and its fences
- [[argocd]] — the app sync a deploy request drives
