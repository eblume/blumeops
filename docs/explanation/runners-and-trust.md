---
title: "Runners and trust"
modified: 2026-10-26
last-reviewed: 2026-10-26
tags:
  - explanation
  - ai
  - design
  - security
---

# Runners and trust

Which runners a workflow can reach depends on whose workflow file runs: main's
jobs and a PR's own jobs differ. The runner inventory is `forge/runners.json`;
the repo list is `argocd/manifests/talos/repos.json`.

## Main's PR jobs run unprivileged

Every job in blumeops's own workflows that runs on `pull_request` lands on an
unprivileged runner. The three that also run privileged on push choose at run
time:

```yaml
runs-on: ${{ github.event_name == 'pull_request' && 'indri-build' || 'indri' }}
```

(`lint.yaml` `workflows-validate`, `forge-reconcile.yaml`,
`indri-flake-check.yaml`). The rest use `indri-build` or
`nix-container-builder`. Privileged workflows (`priv`, `indri-priv`) are
`workflow_dispatch` or `push`-to-main only.

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
| `indri-build` | instance | no | yes (indri-build user on indri) |

## Always trust

The "always trust" setting is not clicked on repos that have a repo-scoped
runner: `blumeops`, `horkos`, `hephaestus` and `talos`.

The trust set is derived, not clicked per repo. A repo is eligible only when
it is `managed` in `repos.json` and no runner in `forge/runners.json` is
scoped to it. The derivation rule is in `forge/action-trust.nix`; its
operation is in [[forgejo-action-trust]].

There is no API for the setting, so the indri launchd job reconciles the
table from the derived set. An accidental manual click on an undeclared repo
is deleted by the next full reconcile.

Trust expires after 90 days unused. The daily job refreshes `last_access`, so
a quiet repo does not lapse. If it did, it fails safe to one click per PR.

**Risk:** unconsented code from a PR on an eligible repo runs host-mode on
indri as the unprivileged `indri-build` user, whose home is the runner's
persistent state and is shared across every repo's jobs. Nix builds there run
unsandboxed through the Determinate daemon.

## Related

- [[forgejo-runner]], [[runbook-forgejo-ci]], [[principals]]
- [[agent-change-process]], [[forgejo-action-trust]], [[privilege-placement]]
