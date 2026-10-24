---
title: Talos v0.5 — where privileged automation lives
modified: 2026-10-24
last-reviewed: 2026-10-24
tags:
  - explanation
  - ai
  - design
  - security
---

# Where privileged automation lives

A decision rule for one recurring question: some automation needs to write to
repos or hosts, so how do we build it without giving talos a way out of its
jail?

The jail's premise is simple. Talos sessions hold only the bot's own identity:
read on canonical repos, write on its `talos/<repo>` forks. Everything stronger
lives somewhere a session can't reach. Every piece of privileged automation has
to keep that premise true. Work through the rules below in order and stop at
the first one that fits.

## 1. Own it first

**An actor acts only on what it created or owns.** Most cleanup and upkeep
fits here, and needs no new privilege at all.

- Talos's fork branches are talos's to delete. The talos *engine*, which is
  deterministic server code and not an agent session, removes a fork branch
  when it sees that branch's PR merged or closed. It also sweeps orphans. It
  uses the bot token it already holds, so the jail gains nothing.
- Horkos opens its own pin PRs, and closes the older ones when it supersedes
  them.

## 2. Declarative over procedural

**If a platform setting does the job, declare it instead of running a job.**

- Forgejo's "delete branch after merge" repo setting, declared by
  forge-reconcile for every repo in `repos.json` and set in project-template,
  replaces a cron that would otherwise need write on every repo.
- Branch protection and required checks are declared too, never clicked.

## 3. A truly cross-boundary write

When something has to write where its author can't, these conditions all
apply:

- **The code comes from reviewed `main`.** A cron or dispatch runs main's
  definition, never a PR's.
- **The credential lives where talos can't read it.** Write on a Forgejo repo
  includes reading its Actions secrets, so a secret is safe only on a repo
  talos can't write. Never put it on a fork, or on any repo the bot can write.
- **On-demand runs go through a horkos warrant**, so a human approves each
  run; see [[warrant-approval-gated-runs]].
- **Use the narrowest scope that works.** A credential spanning many repos is
  a smell. Look again for a rule-1 or rule-2 shape first.

## 4. Host job with a preloaded credential (last resort)

A systemd or launchd unit on a host, holding its own credential, fits when the
credential must sit **outside Forgejo's secret model** entirely. That's either
because no repo's secret scope is safe for it, or because the act isn't a forge
API call at all.

- Precedent: the indri `forgejo-action-trust` job writes `action_user`
  directly. It's declared in [[runners-and-trust]].
- Costs: another credential to rotate, and host state that isn't visible on
  the forge. Make it declared (nix or launchd config from main) and observable
  (a metric or a log line on every run).

## Worked example: branch cleanup (blumeops#1889)

The first plan gave a new forge user write on all 28 managed repos and their
forks, and ran a blumeops cron as that user. That is rule 3 with a very broad
credential. Under this rule it splits into three parts, and none of them needs
a new credential:

| Branches | Created by | Cleaned up by |
|---|---|---|
| Talos fork branches | talos | The talos engine, with its own token (rule 1) |
| Canonical branches, from now on | Erich, horkos | The delete-after-merge setting via forge-reconcile (rule 2) |
| Legacy canonical branches | pre-fork work | A one-time `[human]` run with Erich's own credential |

## Related

- [[runners-and-trust]]: privileged runners, the fork model, "always trust"
- [[hosts-warrants-and-config]]: warrant policy and horkos
- [[security-model]]
