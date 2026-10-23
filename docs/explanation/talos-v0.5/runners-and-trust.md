---
title: Talos v0.5 — runners and trust (instance)
modified: 2026-10-23
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
  - security
---

# Runners and trust (instance)

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

Covers rows V5-25 (closed in Wave 0), V5-65 (approve-and-run) and V5-62 (one
fork model) for this instance. The runner inventory is `forge/runners.json`;
the repo list is `argocd/manifests/talos/repos.json`.

## Main's PR jobs already run unprivileged (V5-25)

Every job in blumeops's own workflows that runs on `pull_request` lands on an
unprivileged runner. The three that also run privileged on push choose at run
time:

```yaml
runs-on: ${{ github.event_name == 'pull_request' && 'indri-build' || 'indri' }}
```

(`lint.yaml` `workflows-validate`, `forge-reconcile.yaml`,
`indri-flake-check.yaml`). The rest use `indri-build` or
`nix-container-builder`. Privileged workflows (`priv`, `indri-priv`) are
`workflow_dispatch` or `push`-to-main only. V5-25 is closed on this
evidence.

The caveat is the next section: this covers *main's* workflow definitions.
A PR's own workflow files still choose their own `runs-on`.

## A PR's own workflow reaches every runner registered to its repo

On `pull_request`, Forgejo runs the workflow files from the PR head, and
those files pick `runs-on` freely. Any runner registered to the repo (or to
the instance) is reachable. Approve-and-run is the only guard.

Live drill, 2026-10-21 (blumeops#1749, run #10206, closed unmerged): a PR's
own workflow ran `runs-on: priv` on `ringtail-priv-runner` as `horkos-runner`,
and `runs-on: indri-priv` on `indri-runner` as `erichblume` on indri. Both
are host-mode runners with ambient power on their host; no secret is needed
to do damage there.

Runner scopes, from `forge/runners.json`:

| Runner | Scope | Privileged | Host-mode |
|---|---|---|---|
| `indri-runner` (`indri`, `indri-priv`) | eblume/blumeops | yes | yes (erichblume on indri) |
| `ringtail-priv-runner` (`priv`) | eblume/blumeops | yes | yes |
| `ringtail-nix-builder-{blumeops,horkos,hephaestus,talos}` | that repo | no | yes (`:host` label) |
| `indri-build` | instance | no | colima build user |

## "Always trust": who gets it (V5-65)

**Decision:** no per-repo "approve and always trust" click. The trust set
is a derived declaration (the rule below), reconciled onto the `action_user`
table by a daily job on indri (PR B, pending; eblume/blumeops#1846), so
talos PRs on eligible repos run CI with no click. The job does a full
reconcile — an accidental manual click on an undeclared repo is deleted
within a day.

**Eligible:** a repo whose PRs can reach no repo-scoped runner, only the
instance-scoped `indri-build` — `managed: true` in `repos.json` and no runner
in `forge/runners.json` scoped to the repo. The rule is implemented twice and
pinned by the shared fixture `tests/fixtures/action-trust/`: python
(`derive_action_trust_policy` in `mise-tasks/forge-reconcile`) and nix
(`forge/action-trust.nix`, the indri consumer). Today that is:

- `agents`, `cv`, `release-kit` (fork pool today)
- `hephaestus.nvim`, `research`, `myeve`, `timberborn-parsimony`,
  `gamedev`, `project-template`, `RexWorks` (canonical-write today; the bot
  pushes same-repo branches, so CI already runs with no click. They need
  the trust click only once V5-62 moves them to the fork model, and V5-62
  waits on it for that reason.)

**Do not click** on `blumeops`, `horkos`, `hephaestus` or `talos`. Each has a
repo-scoped host-mode runner (blumeops also both privileged runners). The
derived rule excludes them by construction — a repo-scoped runner revokes
eligibility at the next derivation — and the reconcile deletes any trust row
that appears there. Moving those runners out of a talos PR's reach is not a
v0.5 row.

**Accepted properties:**

- There is no API to set or read the setting (the web-UI button writes the
  `action_user` table directly), so the trust set is a derived declaration —
  the eligibility rule above — applied by the indri job rather than declared
  per repo; the full reconcile is what catches an accidental manual click.
- It expires after 90 days unused; the daily job (PR B, pending) refreshes
  `last_access` on every run, so a quiet repo no longer lapses. If it ever
  did, that fails safe — back to one click.
- **Risk surface:** unconsented code from a talos PR runs on `indri-build`,
  an unprivileged, lightly sandboxed runner shared by every repo. The
  proper sandbox for that runner is later work.

The readiness view (V5-50) flags any talos PR touching `.forgejo/workflows/`
on any repo.

## One fork model (V5-62)

After V5-62, the `talos` bot has read and a fork (`talos/<repo>`) on every
managed repo, and write on none. Sessions only ever push to their fork.

Changes to `repos.json`:

- `access` and `pool` collapse into one `managed` marker. The `horkos_forge`,
  `release_hook` and `principals` keys stay.
- A new explicit `excluded` list names eblume repos talos never touches
  (e.g. `dotfiles`, archived repos).
- `forge-reconcile --check` fails on any eblume repo in neither list, so a
  new repo can't be silently unmanaged.
- forge-reconcile owns fork creation and fork sync for every managed repo.

Talos server code needs no write-level forge calls: a 2026-10-18 audit found
only issue creation (cron) and comments, both allowed with read access.
Sessions edit only their own comments, which authors may do without write.

Ordering: V5-62 waits on V5-65, because the canonical-write repos lose
click-free CI the moment talos loses write on them. Trust must be clicked
first.

## Related

- [[forgejo-runner]], [[runbook-forgejo-ci]], [[principals]]
- [[landing-gate]], [[agent-change-process]]
