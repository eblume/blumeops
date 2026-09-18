---
title: "Agent Interactive Access: Approved Sessions and Read-Only Exploration"
modified: 2026-09-18
last-reviewed: 2026-09-18
tags:
  - explanation
  - ai
  - security
  - proposal
---

# Agent Interactive Access: Approved Sessions and Read-Only Exploration

> **Status (2026-09-18): analysis only, deliberately not acted on.** This card
> records why talos agents get no interactive privileged access today, what
> the options are if that ever changes, and how they rank. Revisit it when a
> problem shows up that `run-script.yaml`'s one-shot model cannot solve
> without an unreasonable number of approval rounds.

## The question

Agents act on infrastructure through [[warrant-approval-gated-runs|warrants]]:
a request names a workflow, an immutable SHA and frozen inputs; a human
approves in [[horkos]]; CI executes once and reports back. The `run-script`
action extends that to arbitrary bash, so the *scope* of what an agent can
do after approval is already broad. What the model does not offer is
**interactivity**: an agent cannot inspect state and then decide. It either
writes conditional bash that guesses what it will find, or it spends one
human approval round per diagnostic step.

Two things could close that gap: an *approved session* (a human unlocks a
live shell, kubectl or database connection, recorded and time-boxed), or
*read-only exploration* (look steps that need no approval, write steps that
still do). This card was prompted by evaluating
[Warpgate](https://github.com/warp-tech/warpgate), which is the natural tool
for the first of those, against the model we have.

## Warpgate, in one paragraph

Warpgate is a single-binary Rust bastion (Apache-2.0, in nixpkgs). Clients
connect *to* it, it authenticates them (OIDC, TOTP, SSH keys, API tokens),
then bridges them transparently to a pre-registered target: SSH host, HTTP
app, Kubernetes API, Postgres, MySQL, RDP, VNC. Sessions are recorded and
replayable; SSH commands are heuristically logged; Kubernetes API calls and
`exec` sessions are audited. Since v0.29.0 (2026-09-18) a target can
require **just-in-time approval**, so each connection waits for an admin
click, with approvals cached per user, target and source IP. **Access
tickets** grant a user N uses of one target until a deadline, built for
non-interactive clients.

It is not a forward proxy and not a network layer. It cannot replace the
talos egress gateway (which tunnels *any* public destination over CONNECT
and never decrypts) or the Tailscale ingress (which is the L3 network, the
ACL matrix and MagicDNS). Fronting forge or ArgoCD with it adds nothing:
the `agents` bot token and the read-only `argocd` account already attribute
everything. Its only interesting slot here is the protocols the pod is
fenced off from entirely: SSH, kubectl, psql.

## Two gates, compared

`run-script` and a Warpgate JIT session gate the same class of action and
differ in almost every property that matters.

| Property | `run-script` warrant | Warpgate JIT session |
|---|---|---|
| What the human approves | The exact script text, hash-frozen, plus a blumeops SHA | A door: user, target, source IP |
| When the gate acts | Before execution, on content | Before connection, blind to content |
| Deviation after approval | Impossible; a hash mismatch aborts | Unbounded within the target's credential |
| Audit record | Full stdout, stderr, exit code, on the warrant | Session recording plus a heuristic command log |
| Attribution | One warrant, one run | user/target/IP, and every talos session shares all three |
| Where the credential lives | The CI execution context only (invariant 1) | Warpgate holds it; the session borrows the door |
| Reach | The priv runner plus the `blumeops-ci` vault, deliberately narrow | Whatever targets are registered |
| Interactivity | None | Full |

The attribution row bites first. Warpgate caches approvals by user, target
and source IP, and one approval can extend to other targets from that IP.
From the pod, every concurrent talos session presents the same user and IP,
so one click would unlock all of them for the cache period. The
[egress gateway](https://forge.eblu.me/eblume/talos/src/branch/main/docs/design/egress-gateway.md)
already accepts *advisory* attribution; this would make it worse.

The reach row is a separate decision from interactivity. Warpgate SSH
targets would widen *where* privileged action can land, and that should be
decided on its own, not smuggled in with a session model.

## Options, ranked

1. **A read-only exploration action in horkos.** `warrant-policy.yaml`
   reserves the `auto` class ("auto-approved with post-hoc audit") and
   nothing uses it yet. A `run-script-readonly` action bound to a credential
   that can only read (a get/list-only kubeconfig; an SSH user restricted to
   a fixed command set) gives agents cheap look steps while every write stays
   a warrant. Auto-approved runs still mint warrants, so the audit trail is
   unchanged. This keeps all five invariants and needs no new service. **Do
   this first if interactivity ever becomes the problem.**

2. **Horkos-minted Warpgate tickets.** Add a `warpgate-ticket` action: the
   request names target, duration and purpose; the human approves in the one
   queue that already exists; horkos calls Warpgate's admin API to mint a
   ticket for a **per-session** Warpgate user (which sidesteps the
   shared-key collapse above) and the session gets a recorded, time-boxed
   connection. This is the one place Warpgate earns a spot. It also bends
   invariant 1: a ticket is a credential landing in the harness, even a
   scoped and expiring one. Whether a thirty-minute single-target ticket is
   closer to the curated tokens already in the `agents` vault or to the thing
   the invariant forbids is a policy call, and it should be made explicitly
   in that doc before this option is built.

3. **Warpgate's native JIT approvals.** A second approval queue beside
   horkos, door-level approval, and the cache-key collapse. Not worth doing.

There is a fourth mode worth naming because it is a different product:
Warpgate's **live session view**. Approve, then watch the agent's shell in
real time and kill it if it goes wrong. That is supervised interactive
access, the opposite of the warrant model, which is asynchronous by design
so the human can approve later and walk away. It might be right for incident
response with an agent working beside you. It is wrong as a default.

## Cheaper equivalents already in the stack

If the goal is only *human* SSH or kubectl audit rather than agent access,
Tailscale SSH in check mode with `tsrecorder`, and the
[[tailscale-operator]]'s API-server proxy in auth mode, give identity-bound
sessions and Kubernetes audit logs with tools the stack already speaks.
Audited psql to the CloudNativePG databases without a port-forward is the
one small ergonomic win Warpgate would add for humans, and it does not
justify a second identity store.

## Related

- [[warrant-approval-gated-runs]] — the model this would extend; §One-off
  scripts is the gate being compared
- [[horkos]] — the approval queue any option should stay inside
- [[talos-design]] — the access model; egress and ingress are independent
  directions
- [[agent-containerization]] — the fences that make the pod's reach narrow
- [[security-model]] — why there is no public bastion
