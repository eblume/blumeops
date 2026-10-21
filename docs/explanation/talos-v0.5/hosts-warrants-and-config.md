---
title: Talos v0.5 — hosts, warrants and config (instance)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Hosts, warrants and config (instance)

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

The instance configuration talos v0.5 reads from blumeops, and where each
piece lives. Talos reads instance config from mounted files (today the
`talos-repos` and lanes ConfigMaps built from `argocd/manifests/talos/`),
never from a session-writable checkout. New config files below follow the
same path. Paths marked *proposed* are decided in the row that builds them.

## Warrants and horkos (V5-56, Wave 8)

- **Policy:** `warrant-policy.yaml` on main. Talos v0.5 doesn't change it.
  `warrant` actions stay requestable; `auto` actions (`ringtail-rebuild`,
  `provision-indri`, `build-container`) are never filed ([[auto-apply]]);
  `deny` is never filed.
- **Who files:** the engine, when a `warrant` step in an approved plan
  becomes ready, through horkos's existing request path. Sessions stop
  calling `request-run`. Settlement reaches talos as a typed
  `warrant_settled(id, ok)` event (horkos webhook or engine poll).
- **Dedupe on (action, SHA):** when a `warrant` step becomes ready, the
  engine adopts any pending horkos request with the same action and SHA,
  from any requester, instead of filing a second. Horkos's auto-filers
  (horkos#54/#56) must skip when such a request exists from any requester;
  today their idempotency key includes the requester, so a talos-filed
  request wouldn't stop them. That horkos change is part of V5-56.
- **Void on withdrawal:** when a plan revision drops a `warrant` step, or
  the Issue is cancelled, the engine voids the step's unapproved horkos
  request (reason recorded; horkos's existing terminal `voided` state).
  Approved or running requests finish and settle.
- See [[warrant-approval-gated-runs]], [[horkos]],
  [[request-a-privileged-run]].

## Auto-apply hosts

A merge touching `nixos/ringtail/**` or `darwin/indri/**` (and the other
watched paths in `ringtail-rebuild.yaml` / `provision-indri.yaml`) applies
**all of main** to that host, including changes merged earlier that haven't
applied yet ([[auto-apply]]). For talos v0.5:

- Such a merge is a first-class precondition in the plan (V5-30): "this merge
  deploys host X, including pending changes Y" shows before the review ask.
- The `auto_run` step kind (V5-66) watches each merge-triggered run the
  merge will fire, derived from the workflows' `on.push.paths` against the
  PR's touch set. Silent on success; one ask on failure (fix forward /
  revert / I'll handle it).
- The queue's main-settled rule waits on these runs ([[landing-gate]]).
- PR bodies keep `mise run lint-auto-apply`'s block until V5-30 replaces it.

## Auto-sync app map (V5-17 fold, Wave 9)

When a `pr` step merges a change under an auto-sync ArgoCD app's path, the
engine records "auto-deployed: <app> at <sha>" as a step result, so the
cancel sheet and the Issue page show "merged, live on <app>".

*Proposed:* no new file. The map is derived from `argocd/apps/*.yaml`:
each Application's `spec.source.path` with `syncPolicy.automated` set. The
four manual apps (`apps`, `argocd`, `cloudnative-pg-ringtail`,
`external-secrets-crds-ringtail`) have no `automated` key and drop out by
the same rule. Talos receives the derived map as a mounted file generated at
build time, so it never parses blumeops's tree itself.

## Declared state (authoring rule 5)

A step touching a declared-state setting names the owning file, checked
against [[declared-state-files]]. The registry exists and is the authority.
Talos needs it machine-readable; the registry is a Markdown table today.
*Proposed:* a JSON sibling (`forge/declared-state.json` or similar) that the
docs table is checked against, mounted for talos. Decided in V5-17.

## Plan templates (V5-47, Wave 9)

Templates are YAML plan definitions (steps, kinds, params, edges), one file
per template, instance data in blumeops. *Proposed path:*
`argocd/manifests/talos/templates/<name>.yaml`, shipped as a ConfigMap.
Chore templates carry a concurrency policy (default: skip while the previous
run is open). The `trivial` template replaces `!!plan: skip`: one `pr` step
with a budget of path globs plus max files and lines changed.

## Settings (V5-86, Wave 11)

Global and template settings are blumeops server config, changed only by PR.
*Proposed:* `argocd/manifests/talos/settings.yaml` (global) and a `settings:`
block in each template. Issue, step, session and call settings are live in
talos's database. Talos picks up a config change by reload or by
drain-and-restart (V5-70). First global key known now:
`presentation.max_bundle_bytes` (default 100 MB).

## Crons (V5-85, Wave 9)

Repo crons are defined in blumeops (a PR and merge are the consent), with
ids `repo:<name>`. Stored crons live in talos's database (`store:<ulid>`) and
never shadow a repo cron. *Proposed path* for repo crons:
`argocd/manifests/talos/crons/<name>.yaml`, replacing today's `crons.json`
on the session-writable data volume. Repo cron briefs get the same wording
pass as the prompts (V5-72b): no `Closes #N` (the keyword is disabled; only
eblume closes issues), no pragmas, no heph.

## Verify reach per service type (V5-17)

What talos can observe without cluster or SSH access, so a `verify` step is
either talos-run or an evidence-bearing human verify:

| Service type | Talos can observe | Otherwise |
|---|---|---|
| k8s app (ArgoCD) | `argocd app get` read-only (`talos-argocd-readonly`): sync, health, image | — |
| NixOS on ringtail | the `ringtail-rebuild` run result at the merge SHA; Prometheus metrics via `agent-metrics` | host state needing SSH → human verify with evidence |
| nix-darwin on indri | the `provision-indri` run result; `/var/log/indri-rebuild/<sha>.status` reaches talos only through the run log | as above |
| Fly | the `deploy-fly` warrant settlement; the public endpoint over HTTP | — |
| Containers | registry tag presence (`registry.ops.eblu.me`, read) | — |

`agent-health` and `agent-metrics` move behind a read-only broker endpoint
in V5-23 (Wave 8); until then sessions call them directly.

## Related

- [[landing-gate]], [[runners-and-trust]], [[aspects]]
- [[declared-state-files]], [[argocd]]
