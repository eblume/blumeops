---
title: "Warrant: Approval-Gated Privileged Runs"
modified: 2026-08-26
last-reviewed: 2026-08-26
tags:
  - explanation
  - ai
  - security
  - proposal
---

# Warrant: Approval-Gated Privileged Runs

> **The broker is now [[horkos]]** (2026-08-20): the Warrant *service* was
> renamed Horkos (Ὅρκος, the oath daimon) and extracted to its own repo,
> `eblume/horkos`, with auto-release on merge. The *program* documented here,
> the minted **warrant** artifact, `warrant-policy.yaml`, and `warrant-bot`
> all keep their names — a warrant is still what Horkos mints. Historical
> prose below says "Warrant" where it meant the service; read it as Horkos.

> **Status: BUILT AND RUNNING** (2026-08-04). Proposed 2026-08-01, accepted
> after review (PR #455), and delivered across phases 0-4 in the days that
> followed. Agents now request privileged actions with
> `mise run request-run`; Erich approves in [[horkos]]; `warrant-bot`
> dispatches. First self-dispatched run: 713 (`argocd-deploy` on ntfy,
> 2026-08-03). This doc remains the program's north star and its record of
> *why*; per-phase state is below.
>
> | Phase | State |
> |-------|-------|
> | 0 — fences, settings | done (squash-merge off, sshTests applied; forge MFA turned out to predate the phase — see Phase 0 item 3) |
> | 1 — request loop, argocd-deploy | done and proven |
> | 2 — priv runner, audit sweep, vault tier | runner + `verify-runs` + `blumeops-ci` done; **item migration** outstanding ([[blumeops-ci-item-migration]]) |
> | 3 — agent identity, Warrant broker | done; Warrant at v0.3.2, armed |
> | 4 — policy-as-code | `warrant-policy.yaml` enforced at request *and* dispatch |

## The problem

The agent-isolation program ([[agent-workspaces]], [[agent-containerization]],
[[agents-forgejo-bot]]) has landed a working fence: agents author blumeops
changes from a pod with its own `tag:agent` identity, push to a fork, and open
PRs; the bot is read-only on canonical, so it cannot dispatch CI or reach the
deploy-credentialed Actions secrets; the blumeops 1Password vault is
unreachable by construction.

That fence is correct — and it makes every deploy a **human-shaped bottleneck**
with no request channel. Today the loop is: agent opens PR → agent *tells Erich
in chat* → Erich finds gilbert → reviews → merges → dispatches builds → syncs
apps → resets revisions. The agent can neither run a privileged verification
step ("build this container", "sync this app from my branch") nor formally
request one. Work stalls in ways that are invisible unless a session happens to
mention them, and Erich is losing track of the in-flight pieces.

**Goal:** agents make as much progress as possible without human intervention,
against two *firm* boundary classes:

- **(A) Ask-first actions** — things an agent may cause to happen, but only
  after an explicit, authenticated human approval bound to the exact change.
  This class is bigger than it first looks: deploys, container builds, and
  infrastructure applies like `tailnet-up` or `provision-*` all belong here —
  "human approves, agent-demanded machinery executes" is the target shape.
- **(B) Never-agent actions** — credentials and control surfaces no agent path
  may reach at all, with or without approval, because no execution context
  should ever hold them: blumeops-vault *browse* access from the harness,
  Forgejo admin/settings, the approval-granting credentials themselves
  (invariant 4), NAS/backup keys. Class B is about *credentials*, not
  scary-sounding operations — an operation sits in class B only until a
  reviewed script exists to express it as a class-A run. The A/B line itself
  is policy, not architecture; Phase 4 turns it into a reviewed artifact.

The mechanism must put secrets in the **execution context only** (a specific
CI run of a specific script at a specific commit), never in the agent harness.

## Invariants (the load-bearing rules)

Every phase below preserves all five. A change that breaks one is wrong even if
it is convenient.

1. **Harness access stops at the `agents` vault.** "Holds" is broad: a secret
   sitting in plain text in a transcript counts, and so does anything `op` can
   read with the session's service credentials. Note the `agents` vault
   already contains *some* operational secrets (service API tokens curated in
   deliberately, one by one) — so the invariant is not "no operational
   secrets", it is that **the blumeops-tier vaults stay unreachable**: no
   approval flow ever widens what the harness's `op` can read, and no
   blumeops/`blumeops-ci` secret ever lands in a session — approval unlocks an
   *execution context*, not the agent.
2. **Execution binds to an immutable SHA.** Approvals name a full 40-char
   commit, never a branch (branches move after review — TOCTOU). The
   `build-container` short-SHA guard is the precedent. *Corollary: canonical
   must stop squash-merging* — squash rewrites every approved SHA into a new
   commit, so nothing a human approved ever lands on `main` as itself, forcing
   perpetual follow-up-PR churn. Switch the repo to merge-commit (or
   fast-forward) merges; this also dissolves the squash-merge container-tag
   orphaning in [[agent-change-process]] §Build artifacts.
3. **Privileged workflows are a structurally separate class.** Three markers,
   all required, so privilege never blends into ordinary CI:
   - **`workflow_dispatch`-only triggers** — nothing event-driven can start
     one;
   - **`runs-on: priv`** — a dedicated runner label (and, per Phase 2, a
     dedicated runner host) that *only* privileged workflows use and PR-check
     CI never touches. The label split lands with the first privileged
     workflow, even while it temporarily points at the same physical runner;
   - **definitions run from `main` only** — the approved SHA is a *payload
     input* (what to check out / build / sync); the executing definition is
     main's, already reviewed. Agents change privileged workflow definitions
     only via ordinary merged PRs.

   This keeps "the thing reviewed" and "the thing executed" honest without the
   reviewer re-auditing workflow files per request, and never mixes privileged
   and unprivileged jobs in one workflow file or on one runner.
4. **Approval is multi-factor human auth no agent can satisfy.** Whatever
   grants an approval (Forgejo login, Authentik session) must require a
   credential no agent can reach *plus* a second factor. No token an agent
   can read may approve anything — otherwise a prompt-injected agent
   approves itself. *Current factor (decided 2026-08-03): 1Password-managed
   TOTP via Authentik's MFA stage — which gates **both** approval surfaces,
   Warrant and the forge dispatch button alike, since the forge's own login
   is Authentik SSO ([[federated-login]]). Accepted with eyes open that both
   factors then live in the 1Password basket. The upgrade path to
   hardware-backed factors is preserved structurally: Warrant gates
   decisions on an Authentik flow slug, so adding a WebAuthn/hardware-key
   stage is authentik configuration, never Warrant code (see §Hardware-backed
   approval).*
5. **Every privileged run leaves an audit trail** — who approved, what SHA,
   which secrets were exposed, what happened — somewhere agents can *append* to
   but not rewrite (Forgejo run history + heph log).

## What already exists (the underappreciated primitive)

The read-only-bot fence has a flip side that is easy to miss: **because
`workflow_dispatch` is write-gated, a human dispatching a workflow in the forge
UI already *is* an approval gate.** And a multi-factor one: the forge sits
behind [[authentik]] SSO with TOTP enforced, so that button satisfies
invariant 4 with nothing new built. Canonical CI already holds privileged
Actions secrets (`ARGOCD_AUTH_TOKEN`, `FLY_DEPLOY_TOKEN`, `ZOT_CI_API_KEY`,
`MAIN_PUSH_TOKEN`, `FORGE_REPO_WRITE_TOKEN`) that agents provably cannot reach
(fence verified from in-pod 2026-07-31), and the runner executes them on human
dispatch. `mise run container-build-and-release` is exactly this shape.

Two clarifications on that secret surface. Those named Actions secrets are the
**only** blumeops-vault material CI can see — the rest of the vault never
leaves 1Password. And *widening* that set is itself a human-gated ceremony:
Actions secrets are provisioned by the forgejo ansible role, run from gilbert
with biometric `op`. That clumsiness is load-bearing, not incidental — the
provisioning friction *is* the class-B gate on new CI credentials, and nothing
in this design removes it; Warrant only streamlines the per-run
request/approve loop in front of already-provisioned secrets.

So the foundation is **not missing — it is unfinished**. What's missing:

| Gap | Consequence today |
|-----|-------------------|
| No request channel | Agents ask in chat; requests evaporate when sessions end |
| No notification | Erich discovers pending work by logging in |
| No mobile-friendly approve | Approvals wait for a gilbert session |
| Actions secrets are repo-wide | Any dispatched workflow can read *all* secrets — no per-action scoping (Forgejo v15 has no environments/required-reviewers; verify each upgrade) |
| Runner blast radius | CI runs host-mode as `erichblume` on indri — a compromised run is an owner-account compromise |
| Vault is all-or-nothing | 1Password scoping is per-vault; "CI needs the argocd token" currently implies a token that can read *every* operational secret |
| No audit beyond forge | Run history exists but nothing ties request → approval → outcome → heph |

## The design, in phases

Each phase is independently valuable and independently stoppable. Phases 1–2
use only deployed services (Forgejo, ntfy, 1Password, ArgoCD). Phase 3 builds
the one new service. Phase 4 is the autonomy dividend.

### Phase 0 — Housekeeping: clear the decks

1. Dispose of the three open PRs — **mostly done during review**, see
   [§Open PR dispositions](#open-pr-dispositions).
2. **Disable squash-merge on canonical** (forge repo settings; invariant 2's
   corollary) before the first approval-gated run, or approved SHAs never
   land on `main` as themselves.
3. **2FA on the approval surface — satisfied on arrival.** The forge *is*
   behind [[authentik]] SSO, and has been since 2026-02-20 (PR #228), five
   months before this doc was written. Authentik enforces TOTP MFA on its
   default authentication flow, so the dispatch button — Phase 1's entire
   approval gate — was already multi-factor; the break-glass local login
   carries Forgejo's own TOTP on top of that, so there is no password-only
   route to a dispatch. See [[federated-login]] §MFA.

   No Phase 0 action was required. What remains is not a gap but an upgrade:
   both approval surfaces rest on a single 1Password-managed TOTP, and that
   "all eggs in one basket" concern — TOTP secrets living beside the
   passwords they second-factor — is real and is addressed head-on in
   [§Hardware-backed approval](#hardware-backed-approval-analysis-before-phase-3).

Phase 0 mints no credentials.

### Phase 1 — Request loop MVP (“dispatch-as-approval”), no new services

The smallest thing that closes the loop end-to-end:

1. **`mise run request-run <workflow> <full-sha> [-- key=val …]`** (agent-side,
   works with agents-vault creds only). It:
   - validates the SHA is the head of an open PR (or a commit on one),
   - **enforces the SHA binding**: every warrant-class action in
     `warrant-policy.yaml` carries `binds_sha: <input>`, naming the dispatch
     input that must receive the approved commit. A request whose bound SHA
     does not reach that input is refused rather than filed — see
     [§The binding was decorative](#the-binding-was-decorative) below,
   - posts a structured **PR comment**: requested workflow, full SHA, dispatch
     inputs ready to copy, why, a diff link, and a link to the Warrant queue
     entry itself (a bare `#N` in `--why` is wrapped in a code span, because
     Forgejo otherwise autolinks it to a PR of this repo),
   - flags loudly if the diff touches `.forgejo/workflows/**` (per invariant 3
     those changes only take effect after merge — the reviewer should know),
   - **files a heph task** (`Approve: <workflow> @ <sha7> (PR #N)`, project
     Blumeops, attention orange) whose body carries the same links and
     inputs. **heph is the system of record for pending approvals** — the
     information plane, never executive (heph holds no credentials and can
     trigger nothing; invariant 4 untouched). The audit step (Phase 2) closes
     the task when the run lands, so an unactioned request is a visible
     orange task, not a lost chat message.
   - optionally pushes a phone notification — see
     [§Notification channel](#notification-channel-ntfy-vs-heph) below.
2. **Approval = the human dispatches** the named workflow from the forge UI
   (phone browser works — forge is behind the fly proxy) or via
   `mise run approve-run` on gilbert, passing the full SHA as the payload
   input. The auth factor is the Authentik SSO login — session plus TOTP —
   that fronts the forge ([[federated-login]]). Known friction,
   Phase-1-temporary: the dispatch form means copy-pasting the SHA/inputs by
   hand. The request comment and heph task both carry a **direct link to the
   workflow's dispatch page** plus a single copy-paste block; during
   implementation, check whether Forgejo can prefill dispatch inputs from URL
   query params (if yes, the link becomes one-click-then-confirm). Removing
   this form entirely — a true approve button — is Warrant's headline UX win
   and the main reason Phase 3 exists.
3. **New privileged workflows** (definitions on `main`, `workflow_dispatch`
   only, payload-SHA inputs), in rough order of value:
   - `argocd-deploy.yaml` — `argocd app set <app> --revision <sha> && sync`
     (+ a `--revision main` reset mode). Uses the existing `ARGOCD_AUTH_TOKEN`.
     **This is the big unlock**: the “deploy from branch” step becomes
     agent-requestable instead of gilbert-only.
   - `services-check.yaml` — post-deploy verification an agent can *request*
     (or a human can chain after a deploy), pending #439's HTTP-leg rework.
     Interim by design: service verification's destiny is **Grafana** (the
     agent-health / `auth.jwt` read path, heph `01KXREAB…`); the CI wrapper
     is the stopgap that makes it requestable today.
   - **`provision-indri.yaml` / `provision-ringtail.yaml`** — the high-value
     targets, promoted from "later, maybe" to **first Phase-2 deliverables**:
     they are also the largest-blast-radius scripts in the repo (every
     ansible secret, root on both hosts), so they gate on the `blumeops-ci` vault
     split *and* the `priv` runner, not the MVP. provision-indri can run on
     the indri runner (host-mode `op` + SSH-to-self already work);
     provision-ringtail needs a runner that can drive `nixos-rebuild` on
     ringtail — likely the ringtail-side priv runner itself, and it must
     survive the network-restart hang (heph `01KTKW8VD3…`). The ringtail
     side decomposes: `ringtail-rebuild.yaml` lands first, a narrow
     rebuild-only warrant on the priv runner with exactly one root path: a
     polkit rule letting `gitea-runner` *start* the root template unit
     `ringtail-apply@<sha>.service` (which runs `/etc/ringtail-apply/apply`).
     Not sudo — the runner is a systemd `DynamicUser` service, which implies
     `NoNewPrivileges=yes` and cannot be talked out of it, so no setuid path
     works from a job. The full ansible play stays `deny`.
   - `ringtail-rebuild.yaml` — the ringtail-facing half of provision-ringtail
     decomposed out to land first: apply a bound blumeops SHA to ringtail
     by starting the root `ringtail-apply@<sha>` unit from the priv runner
     (polkit-gated). provision-ringtail itself stays `deny`.
4. **A third vault tier** *(the only new credential)*. The two existing
   vaults have clear meanings; the gap between them is exactly where
   privileged execution contexts live:

   | Vault | Meaning | Who reads it |
   |-------|---------|--------------|
   | `agents` | what a session needs to be a useful agent — including some deliberately-curated operational API tokens (invariant 1's nuance) | the harness, always |
   | **`blumeops-ci`** *(new)* | what privileged **execution contexts** read at runtime: argocd token, fly token, zot key, main-push PAT | approved CI runs only, via a **read-only** SA token stored as one new Actions secret (`BLUMEOPS_CI_OP_TOKEN`) |
   | `blumeops` | the whole keys to the kingdom: break-glass admin, every ansible pre_task secret, backup/NAS keys | humans with biometric `op`, **forever** (class B) |

   Why a middle layer at all: CI-runtime items are too hot for `agents`
   (invariant 1), but a CI-readable service account on `blumeops` would hand
   *every* ansible secret to any approved run — 1Password scoping is
   all-or-nothing per vault, so the blast-radius cut needs its own vault.
   The harness gets **no** grant on `blumeops-ci`; the op-shim fence extends
   unchanged. Migrate the static Actions secrets into `blumeops-ci` items over
   time so rotation is one `op item edit`, not a re-provision (subsumes heph
   `01KT5Q9HDJ…` zot-key cycling).
5. **Pilot:** PR #440 (mealie/miniflux). Merge, then run its container build +
   argocd sync through the request→notify→dispatch loop as the acceptance test.

What Phase 1 does *not* fix: repo-wide secret visibility (every dispatched
workflow can still read all Actions secrets — bounded by invariant 3 and the
`blumeops-ci` split), and the runner blast radius. Those are Phase 2.

#### Notification channel: ntfy vs heph

[[ntfy]] is deployed and reaches the phone, but deepening it deserves eyes
open rather than default momentum:

- **What ntfy can do well here:** `X-Click` deep-links a notification straight
  to the PR/dispatch page, and `X-Actions` supports up to three tap buttons
  per message — so "Review diff" / "Open dispatch page" buttons are cheap.
  True *approve/deny* buttons need an endpoint to receive the tap; that
  endpoint is Warrant's API, so before Phase 3 buttons can only deep-link.
- **The costs:** iOS delivery rides the upstream `ntfy.sh` relay, and NVR
  detection volume already sits near the free tier — approvals traffic risks
  the paid tier and deepens a dependency that isn't loved. The topic ACL
  story also needs hardening before approval traffic uses it (topics are
  currently open-on-tailnet; lock `ops-approvals` so only agents publish).
- **The push-free fallback is genuinely fine:** the heph task *is* the
  request record, and pending approvals are just an attention-orange query
  away in the heph PWA / TUI / CLI. No push, no ntfy dependency, nothing
  lost but latency.

**Decision:** Phase 1 is **heph-first** — the task is mandatory, ntfy is an
optional flag (`--notify`) that can be turned off or ripped out without
touching the flow. The deeper ambition threaded through Erich's review —
**heph as the information plane for all of this** (PRs, CI runs, approvals
mirrored as heph nodes; heph informs, never executes) — is adopted as a
design north star and lands with Warrant, whose queue is the natural thing
to mirror into heph wholesale.

### Phase 2 — Scope and blast radius

- **Vault tiering done properly.** Complete the three-tier taxonomy from
  Phase 1: audit which items each workflow actually reads and move *only
  those* into `blumeops-ci`; everything else stays in `blumeops`, human-only.
  Then land `provision-indri.yaml` / `provision-ringtail.yaml` (promoted per
  review — see Phase 1's workflow list for their runner constraints). The
  ringtail-side decomposition starts with `ringtail-rebuild.yaml`: the
  rebuild-only warrant lands on the priv runner first, and the full ansible
  play stays `deny` until this tier completes.
- **Dedicated privileged runner.** Move privileged workflows off
  `erichblume@indri` host-mode onto a purpose-built runner (NixOS container or
  VM, own uid, own `tag:ci` tailnet identity, egress-allowlisted like the
  agent pod) so a hostile job compromises a sandbox, not the forge owner's
  account. The `nix-container-builder` runner on ringtail is the precedent.
  Label split: `runs-on: priv` for secret-bearing jobs; keep `indri` for the
  rest (interacts with PR #439's label rename).
- **Audit plumbing.** A shared post-run step: append run metadata (workflow,
  SHA, dispatcher, outcome) as a `heph log` entry on a standing
  "Privileged runs" heph task, via the hub on indri:8787. Also a weekly ntfy
  digest of runs + pending requests, so nothing silently rots.
- **Drift verification for the dispatch identity** (done). `warrant-bot` is
  minted by a human on gilbert precisely so that granting a persistent
  privileged identity stays a ceremony — but a ceremony's *result* can be
  undone in the forge UI in five seconds, and none of it is version-controlled
  here, so no diff would ever show it. `mise run warrant-bot-drift` asserts the
  four facts that bound the blast radius (exactly write, blumeops only, not a
  site admin, not on `main`'s whitelist) and runs weekly. Read-only by
  construction: creating the credential and checking it are opposite kinds of
  operation and should not share a credential, let alone a job.

### Phase 3 — The Warrant broker (the go-big destination)

A small self-hosted approval service — **`warrant`** — deployed like every
other k8s app (`argocd/manifests/warrant/`, locally-built Nix image,
`warrant.ops.eblu.me` behind [[caddy]], SSO via [[authentik]]). FastAPI +
SQLite (Litestream/PVC), a few hundred lines, boring on purpose.

```
agent (pod, agents-vault creds)                       Erich (phone/laptop)
  │  POST /requests {action, sha, inputs, why}            │
  ▼                                                       ▼
warrant.ops.eblu.me  ──heph task + push──▶  Authentik login + passkey step-up
  │   queue: request → show diff link, action,            │
  │   secret scopes, agent's dry-run output    ◀──approve/deny──┘
  │
  │ on approve: mint a WARRANT = single-use, ≤1h-TTL signed record
  │             {action, sha, inputs, secret-scope, approver, expiry}
  ▼
dispatches the Forgejo workflow (broker-held PAT agents never see),
passing the warrant id; the job's secret step exchanges warrant-id →
exactly the named secret leases (broker-held op SA tokens), single-use
```

Why a broker instead of stopping at Phase 1:

- **Per-request secret scoping.** The job gets the secrets *its warrant names*,
  not the repo-wide set — the thing Forgejo cannot express.
- **Real approval UX.** One queue, mobile passkey approve, request context
  (diff, class, dry-run output) in one screen — instead of forge-UI dispatch
  forms with hand-copied SHAs.
- **Approvals beyond CI.** The same flow can gate "add credential X to the
  agents vault", "run `tailnet-up`", "argocd sync app Y" — any action a script
  can express, uniformly audited.
- **Auditability.** Append-only decision log (who/what/when/outcome), mirrored
  to heph, queryable.

Agent-side auth to the broker: the Authentik service-account groundwork in
heph `01KXREABVH2FZAWKP4R0RN30S8` (client-credentials JWT) — that task becomes
a Phase-3 prerequisite instead of a Grafana-only nicety.

#### Hardware-backed approval (deferred 2026-08-03 — capability preserved)

> **Status:** deferred by decision, not analysis — no hardware key on hand.
> v0.2 ships with the Authentik session + TOTP step-up. The requirement
> below stands as the upgrade path; everything in it becomes an
> authentik-flow configuration change when a YubiKey arrives, because
> Warrant's decision endpoint requires a *flow slug*, not a factor type.
> The spike task (heph `01KZ0G21KZ…`) stays open, dormant.

The requirement, stated precisely: proof that *human Erich* approved the
action, via a physical device that is pocket-portable and works across an
iPhone, a macOS laptop, and a Linux (NixOS/Wayland) desktop.

**Where today's setup falls short:** Authentik TOTP with the seed stored in
1Password is MFA in form, but both factors collapse into the 1Password
basket — a compromised 1Password session (the exact thing an agent-adjacent
attacker would chase) holds the password *and* mints the TOTP. Acceptable
interim, wrong end state for the credential that approves privileged runs.

**Recommended candidate: a hardware FIDO2 key** (e.g. YubiKey 5C NFC —
USB-C covers macOS and the Linux desktop, NFC covers the iPhone; WebAuthn is
native in all three platforms' browsers, and NixOS needs only the udev/
libfido2 bits, declarable in this repo). Authentik's WebAuthn stage can
require **user verification** (PIN/touch) and restrict **authenticator
attestation**, so the approval flow accepts *only* the hardware key — a
device-bound, non-exportable, phishing-resistant credential that lives
entirely outside 1Password. A second enrolled key in a drawer is the
break-glass. Platform passkeys (Face ID / Secure Enclave) can serve as a
convenience tier for lower action classes if wanted — but 1Password-*synced*
passkeys specifically re-centralize into the basket and are excluded from
approval flows.

Deliverable: a research/spike task (file on acceptance of this doc)
validating the Authentik stage configuration and the three-platform tap-to-
approve UX before Warrant's flows are built. Per-class strictness — hardware
key for `provision-*`, platform passkey for a docs build — then becomes an
Authentik flow-policy choice, which is Phase 4 policy material, not new
infrastructure.

The broker is **new attack surface** and must itself pass the fence review: it
holds dispatch + secret-lease credentials, so it is a class-B system — agents
author its code via PR like everything else, never operate it. Tailnet-only
first; public exposure via the fly proxy only if phone-off-tailnet approvals
turn out to matter (Tailscale on the phone probably makes this moot).

### Phase 4 — Policy-as-code and graduated autonomy

Once warrants exist, the approval *policy* moves into the repo as reviewed
data: a `policy.yaml` mapping action classes to outcomes — `auto-approve`
(docs build, ntfy test-post), `warrant` (deploys, container builds),
`deny-always` (class B). Auto-approved runs still mint warrants (audit trail),
and a periodic digest keeps post-hoc review honest. This is the payoff: the
boundary between "agent may do" and "agent may request" becomes a diffable,
PR-reviewed artifact instead of tribal knowledge — effectively the control
plane of a "blumeops v2" without rewriting blumeops.

## Alternatives considered and rejected

- **Full blumeops v2 rewrite.** The fences just landed and verify clean
  (2026-07-31 in-pod check). A rewrite re-opens every one of them for months
  for zero new capability. v2 emerges incrementally as the warrant control
  plane instead.
- **Separate hardware-FIDO job-runner server.** What's rejected is the
  *separate server*, not hardware auth — the hardware requirement is real and
  taken up in §Hardware-backed approval. Authentik already provides the
  WebAuthn machinery; a second bespoke auth system would just be a second
  thing to fence.
- **Approval loads blumeops vault into the harness.** Violates invariant 1
  outright. Execution-context-only is the whole design.
- **Forgejo-native fork-PR run approval** (the "Approve run" button). Reviewed
  and rejected as the primary gate: it approves *running a workflow*, not a
  specific privileged action; secrets exposure on fork-PR events is
  version-dependent; and it evaporates the request/audit/scoping layers. Keep
  PR-check CI on that path; keep privileged runs on dispatch/warrant.
- **GitHub environments + required reviewers.** The right primitive, but
  Forgejo v15 doesn't have it. Re-check at each Forgejo upgrade; if it lands,
  Phase 2 shrinks and Phase 3's scoping half shrinks with it.

## Open PR dispositions

Actioned by Erich during this doc's review (2026-08-02); recorded here as
history plus the follow-ups they leave behind:

- **#439 (honest `indri` runner label + services-check indri leg)** —
  **merged**. Follow-up: confirm no workflow added since it branched (e.g.
  Agent Repo Access) still says `runs-on: k8s`, then drop the compat label at
  the next provision. Phase 2's `priv` label builds on this rename.
- **#440 (mealie v3.20.1 / miniflux 2.3.2)** — still **open**; merge as-is
  (it carries its own breaking-change review), then use its container build +
  argocd sync as the **Phase 1 pilot run**.
- **#441 (remove `tag:homelab → tag:homelab` SSH accept)** — **closed without
  merging**, as proposed, two reasons. (1) It would have broken backups:
  borgmatic's k8s SQLite dumps run `ssh:eblume@ringtail` from indri
  (`ansible/roles/borgmatic/defaults/main.yml`) — homelab→homelab SSH is
  load-bearing; the PR's consumer analysis only checked SSH *to indri*.
  (2) Its motivating hole is properly closed: the agent no longer carries
  `tag:homelab` after the pod cutover (#445–#448), and
  [[agent-containerization]] §"Why we can't just fix the ACL" already
  retracts the patch. Residual follow-up: assert in `policy.hujson`'s ACL
  tests that `tag:agent` has no SSH anywhere, if #445's tests don't already.

## The binding was decorative

Invariant 3 splits a privileged run in two: the *definition* comes from `main`,
and the approved SHA is a **payload input** — what to check out, build, or sync.
Warrant froze that SHA into every record. Nothing made it reach the run.

The two halves lived in different fields and never met. `request-run` sends
`{action, sha, inputs}`; the workflow reads only `inputs`. `build-container.yaml`
declares `ref` as *optional*, defaulting to the dispatch ref, because a human
dispatching from the UI reasonably means "current HEAD". So a request could
name one commit and dispatch another, and did:

> Warrant #22 bound `bcb2b55` (agent-ws 0.15.0). The request passed
> `-i container=agent-ws` and no `ref`. Run 742 checked out `1cb0a614` — main's
> tip — rebuilt the v0.14.0 image that already existed, and reported **success**.
> `verify-runs` then closed the tracking task, and closed superseded #21's task
> from the same run for good measure. Two requests bound to two different
> commits, both marked satisfied by one build of a third.

Every signal was green. The operator error was real, but the system offered no
resistance at any point on the path, which is the part worth fixing.

The repair names the join in the reviewed artifact rather than in code:
`binds_sha: <input>` in `warrant-policy.yaml` says *this* input carries the
approved commit. `request-run` refuses a request that omits it, that passes a
different SHA, or that passes a mutable ref like `main` — a value the workflows
accept and the policy pattern still admits, but which resolves at dispatch time
and so is exactly the moving target an approval exists to pin down. A
warrant-class action with no `binds_sha` at all is refused too, so the hole
cannot reopen by omission when the next privileged workflow lands.

`verify-runs` audits the same property after the fact, and it compares the
**record against itself** — the bound `sha` versus the `inputs` actually
dispatched — never the run's `head_sha`. A dispatched run's `head_sha` is
main's tip at dispatch time, not the payload; comparing against it would fail
every honest approval filed before main moved on. That distinction is the whole
substance of the run-attribution fix in PR #523, and it is easy to lose, because
"compare the run's SHA to the approved SHA" is the obvious wrong answer.

The general shape, which recurs: **a value is not a constraint until something
refuses on it.** Warrant recorded the SHA faithfully from day one, displayed it
in the UI, and put it in the PR comment. It still bound nothing.

## Verify during implementation (assumptions to prove, not facts)

- ntfy topic auth: lock `ops-approvals` before trusting it for approvals
  traffic (server currently treats topics as open); confirm whether approvals
  volume plus NVR volume crosses the `ntfy.sh` relay's free tier.
- 1Password: a service account can be granted **read-only** on a single vault
  (believed yes); minting is a gilbert/biometric step.
- Forgejo v15.0.3: exact `workflow_dispatch` semantics for "definition ref vs
  payload ref" (invariant 3 assumes definition-from-dispatched-ref; the
  Phase-1 workflows must therefore only be *reachable* on `main` — confirm a
  branch on the fork can't shadow them, which read-only-on-canonical should
  already guarantee).
- Forgejo dispatch-page URL: can inputs be prefilled via query params? (Turns
  the Phase-1 approval link into one-click-then-confirm.)
- Forgejo repo settings: disable squash-merge without disrupting the existing
  release workflows' push-to-main behavior (`MAIN_PUSH_TOKEN` path).
- Authentik: client-credentials for the agent SA (heph `01KXREAB…`), and the
  WebAuthn stage's user-verification + attestation-restriction options for
  the hardware-key flow.

## One-off scripts (eblume/horkos#6)

The largest-blast-radius class of action — *run this arbitrary script* — gets
its own warrant class rather than an exception to the model: `run-script.yaml`.

The artifact being approved is the script itself. It travels in the request
inputs as the `(script, script_sha256)` pair; Horkos binds the pair at filing
time (the hash must match the body — a 422 otherwise) and freezes both in the
warrant, so what the approver reads on the confirm page is exactly what the
executor will run. The executor workflow re-verifies the hash before running,
as defense in depth: a body/hash mismatch mid-flight is a hard abort, not a
silent divergence.

The executor reports the full run back into Horkos (durable, on the warrant
detail page): exit code, complete stdout and stderr, start/finish epochs, and
the blumeops checkout SHA it actually ran. One run record per warrant; the
report authenticates with the dispatch token as Bearer. The report finds its
warrant by the forge run number Horkos stamps on dispatch.

The blumeops-ci vault carries `horkos-dispatch` (field `token`), a mirror of
`op://blumeops/warrant-dispatch-token/token` (the warrant-bot PAT). That is
per the one-CI-trust-tier decision above: the tier already includes push to
blumeops main via `forge-main-push`, so the token adds no new tier — and it
lets CI do the one thing its jobs must do, prove the run to Horkos.

One credential has to exist in two vaults because its two readers sit on
opposite sides of a fence: 1Password Connect (external-secrets, feeding the
pod) is provisioned `--vaults blumeops`, and the CI service account can read
only `blumeops-ci`. Neither can be widened without handing one side the
other's whole vault. So the mirror is written by `mise run
warrant-bot-provision` — the same ceremony that mints the PAT — on every run,
not just on `--rotate`, which makes that task the drift check as well. A
hand-copied mirror survives exactly until the first rotation, and it fails as
a 401 in a release job that points nowhere near the vault.

The same PAT was also, until eblume/talos#55 and eblume/horkos#9, a
`RELEASE_FORGE_TOKEN` Actions secret in both of those repos — a third and
fourth copy, each rotating independently. Their release workflows now read the
mirror at job time.

## Deploying horkos

`horkos` is a **manual-sync** ArgoCD application ([[argocd#Sync Policy]]) — one
of five, and the only one that is manual because of what it *is* rather than
what it tracks. Its manifest states the reason: the approval gate for
privileged runs must not redeploy itself from a merge alone. So merging a
change to `argocd/manifests/horkos/` is not the deploy; someone must sync it.

**The deadlock.** The documented way to sync a manual app is `mise run
request-run argocd-deploy.yaml …`, which horkos must *dispatch*. When the
merged change is the one that repairs dispatch, that route cannot run: the
request files, a human approves it, and `consume_and_dispatch` fails for the
same reason it was failing before. Approval succeeds and nothing happens.

**The escape hatch, which is intended rather than a workaround:**

```fish
argocd login argocd.ops.eblu.me --sso     # your own identity, not admin
argocd app sync horkos
```

This does not weaken the gate. Syncing an ArgoCD app from gilbert is already a
human act behind [[authentik]] SSO, and the change being deployed already
passed PR review and merge. The warrant path exists to gate *agent-initiated*
privileged runs, and an agent has no path to either command.

Encountered for real on 2026-08-26: the CoreDNS rewrite broke horkos's
in-cluster HTTPS calls to the forge (eblume/blumeops#708), which made every
approval a silent no-op — including any approval that would have deployed the
fix. Two related failure modes worth knowing, both filed against horkos: a
dispatch that fails *before* `_dispatch` persists nothing and shows the
approver nothing, and a denial records no `decided_by` at all.

## Related

- [[agent-containerization]] — the isolation substrate this builds on
- [[agents-forgejo-bot]] — the identity whose read-only fence is the gate
- [[agent-workspaces]] — isolation model and history
- [[security-model]] — vault and tailnet posture
- heph: `01KXBNMYGHGDVSR5VTRWYXDRGN` (containerization), `01KXREABVH…`
  (Authentik SA), `01KY57XB…` (SSH fence break), `01KT5Q9HDJ…` (zot-ci key
  cycling — subsumed by `blumeops-ci` vault rotation)
