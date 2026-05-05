---
title: Compliance Mute Categories
modified: 2026-05-04
last-reviewed: 2026-05-04
tags:
  - explanation
  - security
  - compliance
---

# Compliance Mute Categories

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

How BlumeOps should categorize muted compliance findings, why a single "compensating control" tag is not enough, and what tooling work is needed to support multiple categories cleanly.

## Why this matters

When a compliance scanner ([[prowler]], Trivy via Prowler IaC, Kingfisher) reports a failing finding, there are three structurally different reasons we might suppress it:

1. **Compensating control (CC)** — the requirement applies and we *do not* meet it directly, but an alternative control mitigates the same risk.
2. **Not applicable (NA)** — the requirement's preconditions cannot be satisfied in our environment, so the finding is structurally inert (e.g. a 32-bit-only CVE on 64-bit-only hosts).
3. **Risk accepted (RA)** — the requirement applies, we do not meet it, no compensating control exists, and we have explicitly chosen to accept the residual risk for a bounded period.

Today every muted finding in BlumeOps uses the `CC: <id>` convention. That conflates all three categories. In a real PCI DSS or SOC2 environment, auditors treat them very differently:

- A CC requires documentation of the constraint, the alternative measure, and recurring validation that the measure still works.
- An NA requires documentation of *why* the precondition cannot be met, with periodic verification that the environmental fact still holds.
- An RA requires an explicit decision-maker, an expiry date, and a scheduled re-decision.

Mixing them under one tag means stale CCs hide stale RAs, and NAs that should be revisited when the environment changes get treated as permanent fixtures.

## Trigger case: CVE-2026-31789

The 2026-05-03 weekly compliance review surfaced [CVE-2026-31789](https://nvd.nist.gov/vuln/detail/CVE-2026-31789), an OpenSSL heap buffer overflow during X.509 certificate processing on **32-bit systems**. Prowler's image scanner flagged 216 findings across 106 BlumeOps images carrying `libssl3` / `libcrypto3` below the fixed versions.

The CVE is genuine, but its preconditions cannot be satisfied in our environment: indri is Apple Silicon (arm64), ringtail is x86_64, and we run no 32-bit containers. This is the canonical NA case — not a CC, because there is no "alternative measure mitigating the risk." The risk does not exist for us at all.

A CC like `no-32bit-runtimes` would technically work, but conflates the categories: if we ever introduce a 32-bit runtime we would have to remember that this CC was load-bearing for the mute, retire or scope it down, and reopen the muted findings. An NA tag with a short justification makes the precondition explicit and self-documents the conditions under which it must be revisited.

## Current tooling state

Three Prowler scans run weekly. Their mute paths today:

| Scan | Mute mechanism | File(s) |
|------|----------------|---------|
| K8s CIS (Sunday) | Prowler `--mutelist-file`, merged from ConfigMap | `argocd/manifests/prowler/mutelist/*.yaml` |
| IaC (Saturday) | Trivy `--ignorefile` shim (Prowler's `--mutelist-file` is a no-op for IaC) | `argocd/manifests/prowler/mutelist/trivyignore.yaml` |
| Container Images (Saturday) | **None — `cronjob-image-scan.yaml` does not pass `--mutelist-file`** | n/a |

The image scan has never been wired to a mutelist. The CSV reports do contain a `MUTED` column, but it is always `False` because no mutelist is supplied. All 14k+ image findings flow through to `review-compliance-reports` unfiltered.

The mute tag convention is consistent across the two configured scans: each entry's `Description:` (or `statement:` for trivyignore) starts with `CC: <id>. <freeform>`. `mise run review-compensating-controls` greps for those IDs to find every file that depends on each control. There is no NA tag, no RA tag, and no expiry field.

## Proposed model

### Tag prefixes

Extend the description-prefix convention:

- `CC: <control-id>. <description>` — references an entry in `compensating-controls.yaml`. Existing convention, unchanged.
- `NA: <reason>. <description>` — environmental precondition fails. Reason should be specific enough that a reviewer can verify it (e.g. `NA: no 32-bit runtimes`, not `NA: doesn't apply`).
- `RA: <reason>; expires <YYYY-MM-DD>. <description>` — explicit risk acceptance with a hard expiry. Past the expiry, re-review is mandatory.

Tag choice is exclusive: a given mute is one of CC, NA, or RA. If two reasons apply, pick the strongest — CC > RA > NA.

### Tooling changes required

1. **Wire the image scan to a mutelist.** Add `argocd/manifests/prowler/mutelist/image-cves.yaml`, mount-and-merge it the same way `cronjob.yaml` mounts its mutelist parts, and pass `--mutelist-file` to `prowler image`. Verify experimentally that `prowler image` honors the flag — Prowler's behavior across providers is inconsistent, and the IaC provider notably does not. If `prowler image` ignores it, fall back to post-scan filtering inside `review-compliance-reports`.

2. **Teach `review-compensating-controls` (or a sibling) to surface NA and RA entries.** CCs already get a staleness queue. NAs should appear in a separate queue keyed on the reason text — when an NA reason becomes false (e.g. we do introduce a 32-bit runtime), every NA mute citing that reason must be reopened. RAs should sort by expiry date, with anything past expiry flagged red.

3. **Expiry parsing.** RA tags carry a hard date. The simplest path is to parse it from the description string at review time. A more durable path is to extend the mutelist YAML schema with a structured `expires:` field and a small wrapper that strips it before passing the file to Prowler. Either works; the structured field is friendlier to editors.

### Out of scope (for now)

- Changing the underlying Prowler mutelist YAML schema. Stay within the `Mutelist:` shape Prowler expects.
- Migrating existing `CC:` entries. The current set is genuinely CCs and should stay tagged that way.
- Building an issue-tracker integration. Todoist is the source of truth for "remember to re-review this" until that scales painfully.

## Order of operations

When this work is picked up, the suggested sequence is:

1. **Scope and confirm.** Re-read this article, confirm the model still fits, adjust if not.
2. **Wire the image-scan mutelist.** Smallest atomic change; produces immediate value (the CVE-2026-31789 mute can land as the first NA entry).
3. **Add the NA convention.** Update [[read-compliance-reports]] and [[review-compensating-controls]] how-tos to describe the three tag prefixes. The convention can land before tooling supports it — review will just be manual until tooling catches up.
4. **Extend the review tools.** Add NA and RA queues to `review-compensating-controls` (or a new task). At this point, parse expiry from RA descriptions.
5. **Optionally: structured expiry.** If RA entries become common, migrate to a structured `expires:` YAML field with a wrapper that filters it out before Prowler reads the file.

The first three steps are a coherent C1. Steps 4–5 can be split off if scope creeps.

## Related

- [[read-compliance-reports]] — the weekly review process this feeds into
- [[review-compensating-controls]] — current CC review tooling
- [[security-model]] — overall security posture
- [[prowler]] — scanner reference
- [[agent-change-process]] — how to scope and execute the implementation
