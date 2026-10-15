---
title: CLI Agent Forgejo Principal
modified: 2026-10-15
last-reviewed: 2026-10-15
tags:
  - reference
  - infrastructure
  - ai
---

# CLI Agent Forgejo Principal

The Forgejo identity for **interactive CLI agent sessions** — Claude Code,
Codex, or any CLI agent operated under Erich's direct, live supervision. It is
the second instance of the [[agents-forgejo-bot]] fork-model pattern: where the
`talos` bot authenticates the talos pod, `cli-agent` authenticates an
interactive CLI session running on a host Erich is sitting at.

**The governing ethos (Erich, 2026-10-14, verbatim):**

> The CLI principal is used only under Erich's direct, live supervision, and
> its secrets are biometric-gated. So a CLI agent (Claude Code or another) may
> "borrow" Erich's human approval for everything up to, but NOT including:
> Horkos approvals, PR approvals, CI approve-and-run, and merges. It may even
> use Erich's personal credentials, but only by getting his sign-off through a
> biometric prompt.

**The motivating incident:** on 2026-10-13 a Claude Code CLI session running
with **Erich's personal forge token** rebased and pushed an existing bot fork
PR. Because the pusher was `eblume` — a repo owner, hence Actions-write —
Forgejo 16 (`services/actions/trust.go`) set `need_approval=false` and ran that
PR's CI as eblume (#1564, #1557, #1563; runs 9254–9273). A human-tier trust
credential thereby approved agent-authored code to run on the runners. This
principal exists so CLI sessions authenticate **as themselves**, and their
identity holds no CI trust anywhere.

## Identity

- **Forgejo user:** `cli-agent` — created by human ceremony HC1 (the same
  ceremony as `talos`, [[bootstrap-agent-workspaces]] §1). Creation is
  deliberately *not* in `repos.json`: `forge-reconcile` manages *grants* on a
  user that already exists; the user itself is the human half.
- **Tier:** a new tier in the #1039 principal-naming scheme, where the name
  is `<tier>-[PROMPT_INJECTION]`, with the tier first — the tier names the
  authorizer. The existing tiers, in the scheme's own words: `ci-` — a
  human approved it by merging to main; `talos-` — the agent decided on its
  own; `horkos-` — a human approved this specific act, via a warrant. The new
  prefix `cli-` names acts authorized by a live, human-supervised CLI session
  (Erich's direct, biometric-gated consent on the host he is at) — so this
  principal is `cli-agent`: tier `cli`, qualifier `agent`. If #1194 (a
  machine-readable principals registry) lands, it is declared there too.

## Access policy

- **Read-only collaborator** on the canonical `eblume/*` repos the talos pool
  authors in — the set declared in `repos.json` by P3 of the #1583 series.
- **Own fork namespace** `cli-agent/`: it authors via cross-repo PRs — the
  same `pool: fork` arrangement the `talos` bot uses on every fork-model
  repo declared in `repos.json`.
- **No write or Actions-write on any canonical repo.** That is the
  load-bearing invariant — it is what makes the no-CI-trust guarantee below
  hold.

### Why this shape yields no CI trust

Forgejo 16 (`services/actions/trust.go`): same-repo branch PRs are always
implicitly trusted; for fork PRs the pusher is trusted iff they have write on
the repo's **Actions** unit. On *user-owned* repos (all `eblume/*`) a
collaborator grant cannot split code-write from Actions-write — so the only
shape that provably gives push without CI trust is **read-only-on-canonical +
own fork + cross-repo PR**. That is this arrangement, and it is already
proven empirically in this fleet: the `talos` bot has run it since mid-2026,
and every one of its fork PRs has sat `pending` awaiting a human
*Approve and run* ([[agent-change-process]]). A rebase-push by `cli-agent`
still needs approve-and-run — re-testing exactly that is the acceptance
criterion for the whole series (verification below).

## The consent fence

The fence has a hard half and a soft half:

- **Hard (structural):** `cli-agent` holds no write/Actions on any canonical
  repo, so it **cannot merge** — merge-to-main capability is withheld by the
  fork model — and it is not a Horkos approver. The hard gate in the ethos is
  the *merge*; everything it may borrow sits upstream of it.
- **Soft (process):** the CLI agent's guidance asks it *not* to approve PRs,
  press Approve and run, merge, or decide Horkos requests. An approval it
  posts anyway is a **process error, not a security failure** — there is no
  programmatic enforcement, and the forge's approval requirement is kept as
  is (Erich, 2026-10-14).

**Talos trust.** talos accepts `cli-agent`'s comments and reviews as human
input equivalent to `eblume`'s — cycle triggers, `REQUEST_CHANGES` steering,
and plan go/no-go — via a configurable list of human-proxy principals (P4, a
PR in eblume/talos in the #1583 series). Today talos only wakes on eblume and
ignores its own bot, which is why `talos` cannot be reused for this.

## Credentials

Both credentials are minted **as the `cli-agent` user** — self-bounding the
same way as [[agents-forgejo-bot]]'s `talos-forgejo-token` (the ownership is
the guardrail, not the scope list) — and stored **concealed** in a
**biometric-gated vault**: the `blumeops` vault or a dedicated one. Deliberately
**not the `agents` vault**: talos sessions read it and could impersonate the
CLI principal.

- **PR-authoring PAT** — scopes `write:repository` + `write:issue`; pushes to
  the `cli-agent/` forks and opens cross-repo PRs.
- **Long-lived read-only talos API token** — for reading the talos issue/PR
  queue, replacing the ~5-minute `talos-m2m` Authentik access token that
  needs blumeops-vault credentials to mint (OQ4(b) of #1583).

Access is via Erich's biometric `op` on the host he is at (ringtail/gilbert).
When Erich is absent the session **cannot authenticate at all** — the absence
is the human-in-the-loop property, not a setting.

## Human ceremonies

All forge-admin + 1Password acts, performed by Erich and tracked in the
`## Human steps` comment on #1583:

1. **HC1** — create the Forgejo user `cli-agent` ([[bootstrap-agent-workspaces]] §1).
2. **HC2** — mint both credentials as that user; store them concealed in the
   biometric-gated vault.
3. **HC3** — point the interactive CLI session's dotfile/shell on
   ringtail/gilbert at the principal's PAT via `op read`, replacing Erich's
   personal forge token.
4. **HC4** — issue the long-lived read-only talos API token for the queue,
   stored alongside HC2's credentials.

## Reconciliation

`repos.json` + `mise-tasks/forge-reconcile` today reconcile exactly one
read/collaborator principal (the `talos` bot) plus the write-only
`horkos-forge`. P2 of the #1583 series generalizes the single `collaborator`
field to a declared principals set, restricted for `cli-agent` to
`access: read` (no `pool`), and applies the same two code-enforced fences —
`PINNED_READ_ONLY` (`blumeops`/`agents`/`horkos`/`talos`) and the refusal of
write on any repo carrying a non-empty `actions/secrets` list. P3 then
declares the read grants.

## Verification

End-to-end, from a CLI session authenticated as the principal (the final
item of the #1583 Human steps):

1. `FORGEJO_TOKEN` resolves to `cli-agent`, not `eblume`.
2. A scratch cross-repo PR's CI sits `pending` — needs Approve and run.
3. **The acceptance criterion:** the principal rebases/pushes a fork PR and
   its CI *still* requires approve-and-run (`need_approval=true`) — the exact
   motion of the 2026-10-13 incident, now failing closed by design.

## Related

- [[agents-forgejo-bot]] — the first instance of this pattern (the talos pod)
- [[bootstrap-agent-workspaces]] — the user-creation ceremony (HC1)
- [[agent-change-process]] — why agent PRs need the approve-and-run click
- [[agent-workspaces]] — the pod workspaces the `talos` bot serves
- [#1583](https://forge.ops.eblu.me/eblume/blumeops/issues/1583) — the
  coordination thread for this series
