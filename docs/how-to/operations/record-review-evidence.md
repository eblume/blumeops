---
title: Record Review Evidence
modified: 2026-04-01
last-reviewed: 2026-04-01
tags:
  - how-to
  - security
  - compliance
---

# Record Review Evidence

How review evidence *would* be captured after a [[review-compensating-controls|compensating control review]], to make the review auditable under a compliance framework.

blumeops does not currently collect review evidence. This card documents the target process for reference and practice.

## Why Record Evidence?

Reviewing a control and updating `last-reviewed` proves the review *happened* but not *what was checked*. Under frameworks like PCI DSS v4.0, a QSA needs to see dated, immutable evidence that the reviewer verified the control and that an appropriate party accepted the residual risk. Compliance platforms like Drata automate this collection, but the underlying artifacts are the same whether you use a platform or a directory of files.

## What Evidence Would Be Captured

For each control reviewed, artifacts should answer:

1. **Who reviewed it** — reviewer name, date
2. **What was verified** — the specific checks performed (e.g., Tailscale ACL policy snapshot, `tailscale status` output, kubectl auth checks)
3. **What was found** — the outcome: control still in effect, circumstances changed, or control invalidated
4. **Residual risk** — what the control does *not* cover (the gap a QSA will ask about)
5. **Acceptance** — formal sign-off that the residual risk is accepted by an appropriate party (reviewer + approver, typically a manager or CTO)

Supporting artifacts would include command output, policy snapshots, screenshots, or API responses — anything that demonstrates the verification was actually performed.

## PCI DSS Context

Under PCI DSS v4.0, compensating controls require a **Compensating Control Worksheet (CCW)** that maps each control to the original requirement it substitutes for. The CCW fields are:

- **Original requirement** — the specific PCI DSS requirement not directly met
- **Constraint** — why direct compliance isn't feasible
- **Compensating control definition** — what is done instead
- **Risk addressed** — how the control mitigates the original threat
- **Residual risk** — what remains unmitigated
- **Validation procedure** — steps to verify (what `notes` captures in `compensating-controls.yaml`)

Req 12.3.2 mandates review **at least annually** (quarterly is typical for Level 1 Service Providers). In a platform like Drata, these map to Controls with uploaded Evidence and review workflows requiring sign-off from both the reviewer and an approver.

## Related

- [[review-compensating-controls]] — The technical review process
- [[security]] — Security posture overview
- [[read-compliance-reports]] — Interpreting Prowler/Kingfisher reports
