---
title: Review Compensating Controls
modified: 2026-03-30
last-reviewed: 2026-03-30
tags:
  - how-to
  - security
  - maintenance
---

# Review Compensating Controls

How to periodically review compensating controls that justify suppressed security findings.

## Review by Staleness

Show controls sorted by when they were last reviewed (most stale first):

```bash
mise run review-compensating-controls
```

This reads `compensating-controls.yaml` (repo root), sorts by `last-reviewed`, and displays the most stale control with all codebase references. It also searches for every file that references the control ID, so you can see exactly which suppressed findings depend on it.

To show more entries:

```bash
mise run review-compensating-controls --limit 20
```

## What is a Compensating Control?

A compensating control is a security measure that mitigates the risk a finding was designed to detect, when the finding itself cannot be directly remediated. For example:

- **Finding:** API server does not enable AlwaysPullImages admission plugin
- **Risk:** Untrusted users could run pods using cached images they shouldn't have access to
- **Compensating control:** `single-user-cluster` — only the operator has kubectl access; no untrusted users can create pods

Controls are documented in `compensating-controls.yaml` and referenced from security tool configurations (Prowler mutelist files, Kingfisher config, etc.) using the format `CC: <control-id>`.

A compensating control is only one of three structurally distinct ways to suppress a finding — see [[compliance-mute-categories]] for when to reach for a CC versus a not-applicable (`NA:`) or risk-accepted (`RA:`) tag instead.

## Review Process

For each control up for review:

1. **Understand the risk.** Read each suppressed finding that references this control. What attack or misconfiguration does the original check guard against?

2. **Verify the control is in effect.** Follow the verification steps in the control's `notes` field. For example, for `tailscale-network-isolation`, check that the cluster is not directly internet-exposed and Tailscale ACLs are enforced.

3. **Assess whether the control actually mitigates the risk.** A compensating control should address the same threat the check was designed to catch, not just be a vaguely related security measure. If it doesn't hold up, either:
   - Fix the underlying finding and remove the suppression
   - Document a stronger or more specific compensating control

4. **Check for changed circumstances.** Has the cluster gained new users? Has a service been exposed publicly? Has an operator added native support for the missing feature? Any of these could invalidate the control.

5. **Update the review date.** Edit `compensating-controls.yaml` and set `last-reviewed` to today's date. Commit alongside any changes.

## Adding a New Control

When suppressing a new security finding, either map it to an existing control or add a new one:

```yaml
- id: my-new-control
  description: >-
    What this control does and how it mitigates the specific risk.
  created: 2026-03-30
  last-reviewed: 2026-03-30
  notes: >-
    How to verify this control is still in effect.
```

Then reference it in the suppression configuration with `CC: my-new-control`.

## Related

- [[record-review-evidence]] — Capturing evidence artifacts for audit (aspirational)
- [[security]] — Security posture overview
- [[read-compliance-reports]] — Accessing and interpreting Prowler reports
- [[review-services]] — Periodic service version review (similar staleness pattern)
