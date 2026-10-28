# no-silent-workflow-failure

Ratchet: no workflow may fail without consequence. A workflow that can run
outside a pull request (push, schedule, release, workflow_run, and so on)
must declare a failure sink, a step that reaches a human or a talos agent
when the run fails. Tracking: eblume/blumeops#1982.

Sinks are of two kinds. (1) A `failure()`-gated step using a **registered**
non-PR reporter (`report-run-failure`, listed in `sinks.yaml`). (2) A Grafana
alert rule in blumeops whose PromQL selects this (repo, workflow) series of
`forgejo_actions_last_success_timestamp_seconds`. An exemption entry in
`sinks.yaml` with a one-line reason is the third, deliberate escape hatch.

**Matcher.** A workflow is *needs-sink* per `classify()` in
`aspects/_forgejo/workflows.py` (not PR-only, not dispatch-only; fail closed).
The step matches when its `if:` is `failure()` (not negated, `!failure()` and
`! failure()` both reject), or `always()` with a `steps.<id>.outcome` /
`needs.<job>.result` equal to `'failure'`; it is not gated on `pull_request`,
and neither is its job. A job with non-empty `needs` only counts if its own
`if:` is itself `failure()`-gated or contains `always()`, since otherwise a
skipped dependency skips the reporter too. Its `uses:` must be
`./.forgejo/actions/<name>` or `eblume/blumeops/.forgejo/actions/<name>[@ref]`,
with `<name>` in the registry. Inline `run:` filers never count.

**Alerts.** Every `argocd/manifests/grafana-*/alerting.yaml` is read; each
`forgejo_actions_last_success_timestamp_seconds{...}` selector in each rule's
PromQL is parsed and checked against `{repo: <identity>, workflow: <stem>}`.
Matchers are `=`, `!=`, `=~`, `!~` with PromQL full-match semantics; a label
the selector does not name is unconstrained, so a bare metric selects all.
But a selector only names a workflow when it has a positive `workflow`
matcher (`=` or `=~`) whose value does not match the empty string: `{repo="…"}`
alone, `workflow!="x"`, `workflow=""`, and `workflow=~".*"` all match no
workflow and count as no sink. Paused rules do not count. The alert tree is
`$BLUMEOPS_ROOT` when set, else the root itself when it is blumeops (identity
`eblume/blumeops`), else no alert tree (a non-blumeops checkout with no
`BLUMEOPS_ROOT` gets no alert sinks). A fork checkout needs
`BLUMEOPS_ROOT` set, or an `upstream` remote pointing at `eblume/blumeops`,
to see the alert rules.

**Known gaps.** The matcher is textual, not a PromQL parser: a selector built
by string concatenation or a `label_replace` that rewrites `workflow` is not
resolved; a rule in another dashboard or Prometheus rule file does not count.
A regex that matches the empty string is rejected outright rather than
evaluated, so `workflow=~"x|"` also counts as naming no workflow.
A reporter is trusted by name: the check does not verify its body. The
registry's `evidence` block is not read by the check.

**Scope.** The aspect runs on every pool repo. `baseline.json` is keyed by
repo (`owner/name`), so each repo's violations are judged against its own list.

**Identity.** The repo label is the canonical `owner/name`: the `upstream`
remote when set (a talos fork checkout is `eblume/blumeops` upstream), else
`origin`. A non-git root has no identity, so no exemption or alert matches
it and its workflows fail closed. Fixture cases are their own mini repo,
identity `fixture/<case>`.

**Static vs halting.** This aspect is static: it proves a sink is declared.
It does not prove the sink fires. A halting check (induce a failure) is a
separate, manual assessment: the procedure below.

**Manual assessment procedure** (per sink type, recorded in `sinks.yaml`
`evidence`):
1. Name the trigger class of one workflow (push, schedule, ...).
2. Name its sink (the reporter step, or the alert rule uid).
3. Induce one failure (a throwaway branch or a failing `run:` on a
   non-main ref, never on main). Record where it surfaced (PR review,
   ntfy, Grafana) and how long it took from failure to that surface.

**Unassessed sinks.** `alert` is unassessed (`evidence.alert` is null). No
Grafana rule exists to induce a failure against, and none is added just for
evidence (Erich, 2026-10-27). The trigger for assessing it: the first workflow
that uses a Grafana alert as its sink. Run steps 1-3 then, in that PR.

**Baseline.** `baseline.json` maps each repo to its needs-sink workflows at
upstream/main, as repo-relative paths: the 16 blumeops entries, plus a list for
each of the nine other repos that has violations. Repos with none are absent
from the object (an absent repo gets an empty baseline). Inline curl filers and
missing sinks stay baselined; each list may only shrink.

**Alternatives rejected.** An invariant (zero violations): blumeops fails at
once, so a ratchet is the honest shape. Lint on `run:` text for curl filers:
the inline filer is the thing being retired, so matching it would reward
the wrong shape. Only the reporter's `uses:` counts, so the registry is the
single place to grant a new sink.
