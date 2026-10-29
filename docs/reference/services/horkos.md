---
title: Horkos
aliases:
  - warrant
modified: 2026-10-17
last-reviewed: 2026-09-16
tags:
  - service
  - ai
  - security
---

# Horkos

The approval broker for agent-requested privileged runs — Phase 3 of
[[warrant-approval-gated-runs]]. Agents file requests; Erich approves in the
UI; Horkos consumes the resulting warrant and dispatches the workflow as
`horkos-forge`. A first-party FastAPI + SQLite service.

**Né Warrant** (renamed + extracted to its own repo 2026-08; Ὅρκος is the
Greek daimon of oaths). The minted approval artifact is still called a
**warrant** — Horkos is the service that mints and consumes them — which is
why `warrant-policy.yaml` and the `Warrant request: #N` PR stamp keep their
names, while the dispatch identity was renamed to `horkos-forge`
(step 1 of blumeops#1039).

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://horkos.ops.eblu.me (tailnet; caddy site) |
| **Namespace** | `horkos` |
| **Source** | https://forge.eblu.me/eblume/horkos (own repo; auto-releases on merge to its main) |
| **Image** | `registry.ops.eblu.me/blumeops/horkos` (locally built Nix, `default.nix` in the horkos repo) |
| **Manifests** | `argocd/manifests/horkos/` — ArgoCD app **auto-syncs** (the reviewed pin-PR merge is the gate; manual until 2026-09-04) |
| **Storage** | 1Gi PVC (SQLite at `/data/horkos.db` — migrated from warrant's DB, schema unchanged) |
| **Agent auth** | Authentik `talos-m2m` client-credentials JWT (JWKS-verified) |
| **Human auth** | Authentik OIDC code flow (`horkos` client), `admins` group, MFA per the authentik flow |
| **Dispatch identity** | `horkos-forge` PAT (`write:repository,write:issue` on blumeops), `op://blumeops/horkos-forge-token` |

## Instance config

The app's per-instance identity is delivered by the deployment, not the image (eblume/horkos#52): scalars as env in `argocd/manifests/horkos/deployment.yaml` (`HORKOS_OIDC_URL`, `HORKOS_HUMAN_ISSUER`, `HORKOS_HUMAN_CLIENT_ID`, `HORKOS_PUBLIC_URL`, `HORKOS_REGISTRY`, `HORKOS_REPO_OWNER`, `HORKOS_REPO_NAME`, `HORKOS_POLICY_FILE`, `HORKOS_PR_ASSIGNEE`), the release-publisher topology as `release-targets.json` in the `horkos-release-targets` ConfigMap, mounted at `/etc/horkos` and selected by `HORKOS_RELEASE_TARGETS_FILE`. Two config surfaces, deliberately — the same shape as talos's env scalars plus `repos.json`/`lanes.json`. From the instance-document release on, every field is required at boot and a missing one names itself in the crash. Optional `HORKOS_GIT_EMAIL` sets the author email of the release publisher's pin-PR commits; unset, a neutral noreply default is used.

The document also carries the merge-hook warrant filers as an optional `auto_filers` key (eblume/horkos#54): one entry per watched prefix, `{path_prefix, action, inputs}`, where an `inputs` value carrying `{sha}` is bound to the merged commit and must be the action's `binds_sha` input in `warrant-policy.yaml`. A main merge touching the prefix files the warrant request itself (bound to the 40-hex SHA) for a human to approve. The key is optional and may be `[]` — an instance with no filers boots; the deployed instance runs the one filer above, watching `argocd/apps/` (the app-of-apps root) and filing `argocd-sync-apps.yaml` at the merged SHA.

## The flow

```
agent: mise run request-run <workflow> <sha> …
   → policy check (warrant-policy.yaml on blumeops main) → PR comment + heph task
   → POST /api/requests            (talos-m2m JWT)
human: horkos.ops.eblu.me → sign in → read the diff → approve…
   → confirm page (full inputs, commit/PR/diff links)
   → warrant minted: single-use, TTL'd, {action, sha, inputs} frozen
   → consumed → workflow_dispatch as horkos-forge → run recorded on the warrant
```

Denials close the request. Anything already executed should be **denied with
a note** — the queue records intent to execute, not history.

The policy file stays in **blumeops**, deliberately: policy and service live
in different repos, so the autonomy boundary and the code enforcing it can
never change in a single PR.

## API

- `POST /api/requests` — file a request `{action, sha, inputs, why, pr, pr_repo}`
  (Bearer JWT); `pr_repo` is the `owner/name` holding `pr`, default blumeops
- `POST /api/requests/{id}/supersede` `{by}` — retire one's own **pending**
  request in favour of a later one (Bearer JWT)
- `GET  /api/requests[?status=…]`, `GET /api/warrants` — read the queue and the decisions
- `POST /api/requests/{id}/decision` `{decision, note}` — approve/deny (session; `admins`)
- `POST /requests/{id}/decide` — the UI form (CSRF-signed); `GET /requests/{id}/confirm`
- `GET  /healthz` — includes `dispatch: armed | armed-no-token | disarmed`
  and the running version (stamped by the release build via `HORKOS_VERSION`)

## Release publishing

For image targets, a tag push in the source repo delivers a Forgejo hook to
horkos, which waits up to 10 minutes for the built image to appear in the
registry and then opens the pin PR bumping the target's blumeops
kustomization — merging that pin is the deploy for the image-target services
(talos, horkos itself).

When the image lands after the wait budget — a cold nix build, for
instance — the `release_events` row ends `failed` with the stable `image_never_appeared:`
error code rather than opening the pin. Recovery is per-target: with the
target's `release_workflow` field set — `release.yaml` for both the
eblume/horkos and eblume/talos image targets, and `cv-release.yaml` for
the eblume/cv artifact target — the source repo's
`action_run_success` for that workflow re-runs the newest failed row that is
newer than the newest published release for the repo; every other failed row
is marked `superseded`, because publishing a version below the newest
candidate would open a downgrade pin PR that superseding never closes. The
failed→pending claim is atomic, so a recovery sweep and a manual Forgejo
Redeliver of the tag webhook can't both publish. A failed row is also
logged at WARNING naming repo, version, and reason, and the home page's
Recent releases table shows the last ten rows with their state — no
separate alerting
([eblume/horkos#61](https://forge.ops.eblu.me/eblume/horkos/pulls/61), deployed in v0.5.44).
The artifact flow is the same shape with a different failure code: when a
cv tag push outlives the same wait budget for its Forgejo release asset
(`cv-vX.Y.Z.tar.gz`), the row ends `failed` with `asset_never_appeared:`
instead, and the `action_run_success` sweep from `cv-release.yaml`
re-publishes it on the same rules — the re-dispatch re-waits on the now-present
asset and proceeds to the pin PR that bumps `caddy_cv_version` in
`ansible/roles/caddy/defaults/main.yml`
([eblume/horkos#62](https://forge.ops.eblu.me/eblume/horkos/pulls/62), deployed in v0.5.44).
Container pins (blumeops `containers/<name>/`) recover without a Redeliver.
When a container's image lands after the budget, its row ends `failed` with
`image_never_appeared:` and no pin PR opens. The next successful
`build-container.yaml` run on main re-runs it: horkos re-checks each failed
row's image and re-dispatches the row if every image it names is present.
Recovery is scoped per container, so a newer published pin for one container
never supersedes a failed row for another. A row is superseded only by a newer
failed or published row for the same container.

If a container pin is missing after its image was built, re-run the
`build-container.yaml` run on main from the forge Actions UI. A re-run that
completes emits the same `action_run_success` delivery, so this works without
finding the push delivery in the hook's Recent deliveries list. Check the
horkos log for `container recovery` lines, then confirm the pin PR exists.

A target without
`release_workflow` set never auto-recovers — its failed row stays `failed`
for a manual Redeliver from the Forgejo webhook's Recent deliveries.

## Operating it

- **Deploy**: merge the auto-opened `horkos-release-vX.Y.Z` pin PR. That is
  the whole deploy — the app auto-syncs, like talos. Confirm with
  `curl -s https://horkos.ops.eblu.me/healthz` (`version` field) once ArgoCD's
  reconciliation interval has passed.
- **Disarm**: set `HORKOS_DISPATCH_ENABLED: "0"` in the deployment and sync.
  The credential stays in place, ignored; decisions still record, and
  dispatch falls back to a human in the forge UI.
- **Check the power is real**: `curl -s https://horkos.ops.eblu.me/healthz` —
  `armed-no-token` means the ExternalSecret isn't resolving (the failure that
  once looked exactly like "disabled").
- **Rotate the dispatch PAT**: `mise run horkos-forge-provision -- --rotate`
  (gilbert; needs an ephemeral `write:admin` token, see the script). One live
  dispatch key is the invariant: the new PAT is minted as `horkos-forge` and
  verified (its id in horkos-forge's token list + a push-reporting read of
  `eblume/blumeops`) **before** anything is
  stored, then every predecessor whose name matches `horkos-forge-*` or
  `warrant-dispatch-*` is revoked and the token list is re-read to assert
  exactly one dispatch token remains (`--keep-others` opts out). After a
  rotation, force ESO to pick up the new value before restarting: the k8s
  Secret `horkos/horkos-dispatch` holds the predecessor until ESO's 1h
  refresh, and a rollout restart before that re-reads a dead token.

  ```fish
  kubectl --context=k3s-ringtail -n horkos annotate externalsecret horkos-dispatch force-sync=$(date +%s) --overwrite
  kubectl --context=k3s-ringtail -n horkos rollout restart deployment/horkos
  curl -s https://horkos.ops.eblu.me/healthz   # expect armed, not armed-no-token
  ```
- **Scope**: only actions with `class: warrant` in `warrant-policy.yaml` are
  requestable — today `argocd-deploy.yaml`, `argocd-sync-apps.yaml`,
  `deploy-fly.yaml`, `forge-bot-pat-rotate.yaml` (the talos Forgejo bot PAT
  rotation), and `run-script.yaml` (one-off scripts). Its former deny member, `provision-ringtail.yaml`, was retired
  in #1527; the class remains defined for any future workflow that must read
  the human-only `blumeops` vault.
- **Cluster credential for run-scripts**: the `run-script` ServiceAccount in
  this namespace (ClusterRole `run-script-pv-ops`: `persistentvolumes`
  `get`/`list`/`delete`, `persistentvolumeclaims` `get`/`list` — no secrets,
  and no other cluster-scope grants; the namespaced `run-script-talos-rollout`
  Role in `talos` covers the CI pod roll with `get`/`list`/`patch`/`watch`
  on the named `talos` Deployment) backs
  `blumeops-ci/k3s-run-script`, the only non-root k3s
  credential. Rotation is a human act on ringtail: re-mint
  `kubectl create token run-script -n horkos --duration=8760h` as root,
  `op item edit` the vault item, and file the rotation reminder a month
  before expiry; deleting the ServiceAccount is the kill switch.
- **Test it**: the service suite lives in the horkos repo (`scripts/test`
  there, and its CI). `mise run horkos-test` here covers the blumeops-side
  client tooling (`request-run`, `verify-runs`). Neither needs a forge token,
  cluster, or vault.

## Run attribution

The run a warrant names comes from the dispatch itself. Forgejo's dispatch
endpoint answers 204 with no body by default, but with `return_run_info: true`
in the request body it answers **201** naming the run it created — so there is
nothing to infer, and no window in which an unrelated run could be taken for
ours.

A dispatch that answers any other way — 204 from a forge that ignores the
flag, or a body carrying no run number — leaves `run_number` null and links
the workflow's run list. That is the intended outcome, not a degraded one: a
warrant asserts that a human authorized a *specific* run (invariant 5), so a
confidently wrong link is worse than an honest absence. `dispatched_at` is
recorded alongside, which makes a bad link falsifiable after the fact.

Since v0.3.4, `GET /api/requests` serializes each request's latest warrant
(`decision`, `decided_by`, `run_number`, `run_url`, `dispatched_at`) so the
recorded link is consumable outside the database — `mise run verify-runs`
uses it to close approval tasks against the exact run their approval caused.
Forge-side inference remains only where there is NO recorded warrant link at
all (pre-stamp tasks or a warrant outage). A warrant record without a
`run_number` is reported, never guessed, in four ways: request status
`dispatched` means the dispatch ran but the forge never named the run (a
pre-`return_run_info` forge / 204 answer) — **dispatched-norun**, left for a
human to link or re-dispatch; request status `dispatch_failed` means the
dispatch attempt failed — reported, its reason on the warrant note, left
open; a `voided` request (void_reason `pr-closed` / `policy-retired`, from
eblume/horkos#35's void handlers) is **settled** rather than never-
dispatched — the sweep closes the tracking task with the void reason instead
of leaving it open; any other run-less status (approved / denied /
superseded) was **never
dispatched**, and when the warrant note records the pre-dispatch no-op reason
(` | not dispatched: …`), the sweep surfaces it (eblume/horkos#13). The run
heuristic is refused for all four, never consulted (eblume/horkos#12).

## Superseding

A PR that takes review feedback moves its head SHA, so the request bound to
the old commit is dead on arrival of the new one — but it stays `pending`, and
the queue then shows two near-identical entries with nothing to say which is
live. `POST /api/requests/{id}/supersede {"by": <new id>}` retires the old one:
status `superseded`, with `superseded_by` naming its replacement, rendered in
the UI as `superseded → #N`.

It is the only write an agent identity may make to an existing request, and it
can only ever **reduce** (invariant 4). `superseded` is not `pending`, so the
decision path refuses it: no warrant, no dispatch, no way back. The route is
scoped to the caller's own still-pending requests, so an agent can neither
retire another identity's request nor undo a human's decision.

`mise run request-run <workflow> <sha> --supersedes <id>` is the whole loop
from the agent's seat: file the new request, retire the old one, note the
supersession on its PR comment, and close its heph tracking task (matched by
title *and* the `Warrant request: #<id>` stamp — an ambiguous match closes
nothing and says so).

## Known gaps

- **UI ergonomics** — keyboard patterns, filtering, search, embedded diff
  view (heph `01KZ4NH4MF…`). Approval ergonomics *is* the approve-fatigue
  mitigation, so this is substance, not polish.
- **Hardware-backed approval** — TOTP today; the flow-slug design means a
  WebAuthn stage is an authentik change, not a Horkos change (heph
  `01KZ0G21KZ…`).
- **Secret leasing** — deliberately never built; CI reading its own secrets
  from `blumeops-ci` may make it unnecessary.
- ~~**Stale Authentik leftovers**~~ — done 2026-08-23: the old `Warrant`
  provider/app (left behind because blueprints don't prune) were deleted via
  the Authentik API, alongside the orphaned `warrant` namespace/PVC and the
  ghost dashboard tile. The pre-migration `warrant.db` is parked at
  `ringtail:/root/warrant.db.pre-namespace-delete-2026-08-23`.

## Related

- [[warrant-approval-gated-runs]] — the program, its invariants, and why
- [[request-a-privileged-run]] — the request side, from an agent's seat
- [[blumeops-ci-item-migration]] — the vault tier and what never moves
- [[authentik]] — identity provider (`talos-m2m` and `horkos` blueprints)
