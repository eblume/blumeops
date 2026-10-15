---
title: "Auto: Merge-Approved Host-Config Apply"
modified: 2026-10-15
last-reviewed: 2026-10-13
tags:
  - explanation
  - ai
  - security
---

# Auto: Merge-Approved Host-Config Apply

`class: auto` is the third answer to the question every privileged action
asks — *who looked at this before it ran?* — alongside `warrant` (a human
looks at each run) and `deny` (no CI context may run it at all). This
document is the design record for the class: what it means, the one job the
merge commit must do to earn it, the failure modes honesty requires naming,
and what stays behind the warrant. It completes
[[warrant-approval-gated-runs]] Phase 4 and ships the class for host-config
apply (#1525).

## What the auto class is

`warrant-policy.yaml` assigns every privileged workflow one of three classes.
Each class answers one question — and the answer is about *who looks*, never
about which credentials a run reads:

- **`deny`** — CI cannot run this at all, because it needs the `blumeops`
  vault, which is human-only; nobody files it. Its only member,
  `provision-ringtail.yaml`, was retired in #1527; the class remains defined
  for workflows that would read the human-only `blumeops` vault.
- **`warrant`** — CI can run it, and a human must look at each individual
  run. The look is a bound MFA approval in [[horkos]].
- **`auto`** — CI can run it, and the PR review that produced the merge
  commit *is* the look.

The vault tier does not distinguish warrant from auto: every CI run —
warranted, auto, or merge-triggered — is capped at the `blumeops-ci` vault
tier, and the `blumeops` vault is human-only (invariant 1). "Auto" is not
"warrant with the approval skipped"; it is a different answer to the same
question, earned by a different property of the action.

## The precondition: the merged diff is the whole of what executes

An action may be `auto` only when the merged diff is the whole of what
executes. A nix rebuild or a nix container build satisfies this by
construction: the entire input is a SHA, and the SHA *is* the build input —
nothing arrives at run time that was not already merged and reviewed.
`run-script` cannot satisfy it: the script body arrives at request time, so
there is no merge commit a reviewer could have looked at. It stays `warrant`.

## Naming, not inventing

`build-container.yaml` has been auto in everything but name for months:
`on: push` to main with `paths: containers/**`, reads the `blumeops-ci` zot
key at job time, pushes to the registry only on main. This change names it
`class: auto` and adds two more: `ringtail-rebuild` (nixos-rebuild switch on
ringtail via the priv runner) and `provision-indri` (nix-darwin rebuild on
indri via the host-mode indri-priv runner).

No warrant is minted for an auto run, and that is load-bearing, not an
omission. A warrant exists to bind a human MFA approval to one action plus
one SHA. An auto action has neither need: the merge to protected main *is*
the human approval, the merge commit *is* the bound SHA, and the apply reads
nothing a merge-triggered job cannot already read. A policy-minted warrant
with no human decider would corrupt the one record that means "a human
looked at this SHA": `verify-runs` would have to treat it as an approval it
never was, settlement comments would carry a phantom approver, and the audit
digest would each need a "was it really a human" branch. The class is honest
by refusing to mint.

## The trigger

Auto actions are event-triggered Forgejo pushes, not requestable: `on: push`
to main with a `paths:` filter, applying the push's own SHA (`github.sha`).
`request-run` refuses `class: auto` exactly as it refuses `deny`, and horkos
already fail-closed-refuses any class other than `warrant` at dispatch.

This is the one documented exemption to the invariant-3
`workflow_dispatch`-only marker for privileged workflows
([[warrant-approval-gated-runs]] invariant 3; the exemption is stated
precisely in [[agent-change-process]] §What the click does not protect). The
exemption is exactly as wide as the gate below makes it.

## The merge-commit gate

Both host workflows run a `gate` job before anything privileged touches the
machine: `GET /repos/eblume/blumeops/commits/{github.sha}/pull`. A 200 with
`merged == true` and `merge_commit_sha == github.sha` proceeds; anything
else — a 404, a mismatch, a non-merge commit — is refused red, with an ntfy
post to `ops-approvals`.

Verified 2026-10-13: the endpoint returns 200 exactly when the SHA is the
merge commit of a merged PR; all 219 merged blumeops PRs in the last 250
carry a `merge_commit_sha`; zero squash or rebase merges. The consequence is
the property: a raw push to main — for example `MAIN_PUSH_TOKEN`'s release
push — lands on main but triggers no auto-apply, because a raw-push commit
is not a PR merge. The gate runs unauthenticated (the repo is public-safe)
and before any secret-bearing step.

The honest caveat: a future switch to squash or rebase merges would silently
disable the auto path — a merged commit would no longer carry the push's SHA
— until the gate was taught to accept the new shape. The ntfy-on-refusal
makes that failure loud rather than silent.

## Honest scoping of main-write

The whitelist for push/merge to main is `eblume` alone: forge-reconcile's
`check_main_whitelist` asserts exactly that — no non-eblume identity sits in
the whitelist. But the eblume-scoped PATs held in the `blumeops-ci` vault
*are* eblume: `FORGE_REPO_WRITE_TOKEN` (an eblume PAT, `write:repository`,
which can merge a PR through the API) and `MAIN_PUSH_TOKEN` (raw
`git push HEAD:main`). So a CI job holding an eblume PAT can merge a PR, and
therefore can trigger an auto-apply. Branch protection alone cannot enforce
the invariant here, because the whitelist really is just eblume.

The accepted trust statement is therefore stated plainly: **nothing may merge
to canonical main other than eblume, or identities whose credential tier is
below blumeops-ci; any credential that can merge a PR can thereby auto-apply
host config, and the accepted property is that `blumeops-ci`-vault holders
are the same trust tier as main itself** — `MAIN_PUSH_TOKEN` already writes
main today. The follow-up on narrowing them (#1560) settled on acceptance
without re-mint; the decision is recorded in **Known main-write
credentials** below. forge-reconcile's assertion keeps its real job — no non-eblume
identity in the push/merge whitelist — and this section names its blind
spot.

### Known main-write credentials

Decided 2026-10-13 (#1560): both credentials stay as they are — accepted
main-write credentials at the `blumeops-ci` tier, no re-mint.

- **`FORGE_REPO_WRITE_TOKEN`** — eblume PAT held as a repo Actions secret,
  used by forge-reconcile. Audited: none of its writes — collaborator,
  webhook, label, Actions-secret, and (human-run only) branch protections —
  needs merge or push, but on this Forgejo (16.0.2, Gitea 1.22.0) PR merge
  sits under the `repository` token category, so merge is inseparable from
  `write:repository`. The scope is already the minimum that
  allows its real writes; a merge-less re-mint is not achievable.
- **`MAIN_PUSH_TOKEN`** — eblume PAT read from the `blumeops-ci` vault at
  job time, doing the raw `git push HEAD:main` in the blumeops release
  workflow. Its raw-push route is gate-inert: a raw push is not a PR merge,
  so the merge-commit gate refuses it — no apply. The release push is a
  deliberate, dispatch-triggered, eblume-authenticated op.

The one lever that would structurally close the merge route — moving
`FORGE_REPO_WRITE_TOKEN` to a dedicated non-eblume bot account absent from
main's push/merge whitelist — was considered and rejected: forge-reconcile's
real writes (collaborator PUT/DELETE, webhooks) need repo admin, and a repo
admin can edit branch protection, i.e. add itself to the merge whitelist and
then merge. A non-eblume bot carrying those writes is still a main-write
credential, one API call removed; it costs a new principal and buys nothing.
Do not re-propose.

The rationale is the standing policy that all CI in `eblume/*` is one trust
tier: CI credentials are trusted because workflow code only runs from
human-merged main or warrant-gated dispatch, not because each token is
minimal.

## New invariant: nothing automated may gain merge rights

Main is now the approval surface for auto actions, so a sixth invariant
follows from the first five: **nothing automated may ever gain merge rights
on canonical main.** Branch protection — no push or merge for any bot or CI
identity — is what makes the auto class safe, and it is already true:
Forgejo's *Approve and run* gating on external PRs keeps CI-authored PRs
from touching main without a human, and `horkos-forge` holds no merge
credential. The moment an automated identity can merge, it can also approve
an auto-apply, and the class's whole point — the human review is the gate —
is gone.

## Runner preflight

Before consuming anything privileged, a `preflight` job queries
`GET /repos/{repo}/actions/runners` with a dedicated Actions PAT scoped
exactly `read:repository`: the runners endpoint sits in the repository
scope category (GET derives the read level), and `read:actions` does not
cover runner management — Forgejo keeps the runner/secret/variable routes
on the repository scope — so the token's user must own the repo. No write
scope, hence no merge capability; the property that matters is a PR job
that ever sees it gains nothing. Never the write PAT. The secret is
declared in `forge/actions-secrets.json`, its value source in
forge-reconcile's `ACTIONS_SECRET_SOURCES` allowlist
(`op://blumeops-ci/forge-actions-readonly/token`); the human mints the
`read:repository` PAT, stores it in that `blumeops-ci` item, and runs
`mise run forge-reconcile` from gilbert, which PUTs the Actions secret.
Declaring the name (not hand-setting it in the forge UI) is what makes
forge-reconcile authoritative for both name and value: `--check` fails on
any live secret name missing from the file, and a hand-set value would
never pass through the allowlisted 1Password source. The preflight fails
closed:
a missing token, an unreachable API, or no online runner for the required
label means the run goes red with an ntfy post to `ops-approvals`. The
online means the runners API's own server-side status (`idle`/`active`),
stricter than request-run's 10-minute Prometheus threshold (#1515).

The preflight is complementary to the #1515 queue-stuck alert:
`ForgejoCIQueueStuck` catches a label that dies *between* check and pickup,
which dispatch-time preflight cannot; the preflight catches the
unserved-label case at dispatch time, fast. `build-container.yaml` gets no
preflight: its build fleet is ordinary CI, already covered by
`ForgejoRunnerOffline` and queue-stuck.

## SHA selection

`REVISION` is chosen by the event, never by a mutable ref:

```
REVISION = (github.event_name == 'push' && github.sha) || inputs.revision
```

On push, the dispatch input is ignored by construction; on dispatch it is
required, as today. The existing shape gate (40 lowercase hex) and the
main-ancestry check run on both paths, so the two trigger types cannot drift
in what they will apply.

## Failure model

The class cannot pretend to know more than the run mechanics allow.

- **indri is fire-and-forget** (#1266): a green run means *launched*, not
  *switched*. The outcome is `/var/log/indri-rebuild/<sha>.status` on the
  host (written when the switch ends), not the run's own exit code. #1566
  adds the ringtail `.status` sidecar and per-host watchers that ntfy on
  any verdict other than success.
- **ringtail: green means applied** — except the documented nixpkgs-update
  case: when the applied commit restarts the priv runner unit, the job dies
  mid-rebuild and goes red even though the profile applies. The run log's
  streamed tail explains itself (the log ends in the rebuild's own output),
  and the sidecar holds the true result. A red run on a nixpkgs update is
  expected, not a rollback signal.

## Concurrency

Each host workflow carries a top-level `concurrency:` group — the
workflow's own name, `cancel-in-progress: false` — so two runs of the same
workflow never overlap, including the `gate`/`preflight` jobs that run on
a different label. `priv` is one scoped instance (capacity 1) and
`indri-priv` one host-mode runner: the capacity-1 apply labels are a
second serialization layer, and merge order is preserved — newer runs
queue, never cancel. Each run applies its own SHA, in merge order — the
queue order is the merge order, and the gate binds each run to its own
commit. Two launcher-side guards (#1566) keep an out-of-order outcome from
being possible even when the queue can't:

- **supersede-skip** — right before its switch/rebuild, each host checks
  whether `origin/main` has moved past its own SHA (`git fetch` +
  `merge-base --is-ancestor`) and, if so, records a `superseded` sidecar
  and exits clean instead of applying a commit a newer run is already
  bringing; the run stays green and the watcher treats `superseded` as
  silence — expected, not a failure.
- **launcher lock** — indri's detached `darwin-rebuild switch` holds an
  atomic `mkdir` lock (macOS has no flock; stale reclaim by pid file, a
  ~30-minute cap, then a `lock-held` sidecar), so two switches can't race
  with the older SHA finishing last. Ringtail adds a `flock` on top of
  the capacity-1 queue (a `busy` sidecar on contention).

## When the apply breaks the host

If an auto apply breaks networking, tailscale, or the priv runner itself,
no next merge can reach the host to repair it, and the watcher's ntfy may
not get out. This case needs a human at the console (physical or VM
access); the digest line plus the red run are the after-the-fact record. A
post-switch connectivity check with automatic rollback in `ringtail-apply`
is a considered, deferred follow-up — deliberately not in scope here,
because its failure modes are themselves complex enough to want their own
review.

## What stays warrant and deny

The class boundary does not move for actions whose merged diff is not the
whole of what executes:

- **stays `warrant`:** the four manual ArgoCD applications
  ([[argocd#Sync Policy]]), `deploy-fly`, and `run-script` — the last
  because its script body arrives at request time;
- **stays `deny`:** *(no current members)* — its only member,
  `provision-ringtail.yaml`, was retired with the play in #1527; the class stays
  defined for any future workflow whose merged diff cannot be the whole of
  what executes, e.g. one that must read the human-only `blumeops` vault.

## The digest: post-hoc audit

Auto runs get review after the fact, not before: a weekly ntfy digest of
auto-applied runs — assembled from forge run history plus the host sidecars
— posts to `ops-approvals`, and each run appends a per-run heph log under a
standing task. The digest is review, not the alarm: it exists to catch a
merge that should not have happened, while the gate, the preflight, and the
red-run notifications catch the failure to apply.

## Agent duties

An agent that opens — or materially edits — a blumeops PR whose diff touches
an auto-apply host path must say so in the PR body before merge: run
`mise run lint-auto-apply --pending <host>` (and `mise run
lint-auto-apply <pr>` after pushing) and paste the printed block — the plain
`Auto-apply: <host>` declaration line, one per affected host (a declaration
for humans, deliberately not a `!!` pragma) plus the lint's list of pending
host changes on main that the merge would also apply. The block must be
refreshed whenever main moves, and the pending items must be named *inside*
the block's blockquote — the lint only counts #NNNN/sha8 mentions there, not
elsewhere in the body. indri is fire-and-forget, so its block carries the
"green means launched" note and its pending list may over-count.

The lint is the source of truth for which hosts are affected and what is
pending — it derives both from warrant-policy.yaml and the workflows'
`on.push.paths`, so do not copy a path list into prose. A host's trigger set
includes the shared input files its config imports (`forge/runners.nix` →
`forge/runners.json` for both hosts, listed in each workflow's `paths`): a
change to a shared input is a pending host change for every host that
imports it. The derivation fails closed — a `class: auto` workflow that does
not list a host glob (or is not in the lint's `NON_HOST_AUTO_WORKFLOWS`
allowlist, build-container) makes the lint exit 1, including when the PR's
own version of the workflow (or policy) is what is broken: a PR cannot
bypass the check by breaking its own workflow. The same check runs in CI as
`Lint / auto-apply` on every PR, so human PRs and late merges cannot skip it
either.

## Related

- [[warrant-approval-gated-runs]] Phase 4 — the policy-as-code phase this
  class completes
- #1525 — the auto-apply program this PR ships
- #1560 — the scope decision for the known main-write credentials
- #1515 — the runner-availability preflight and queue-stuck alert
- #1358 — the privileged-runner label scoping the auto runs depend on
- `.forgejo/workflows/ringtail-rebuild.yaml`,
  `.forgejo/workflows/provision-indri.yaml` — the two host workflows this
  document covers, with `build-container.yaml` the third auto action
