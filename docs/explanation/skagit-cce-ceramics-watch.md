---
title: Skagit CCE ceramics watch
modified: 2026-09-01
last-reviewed: 2026-09-01
tags:
  - explanation
  - ringtail
  - decommission
---

# Skagit CCE ceramics watch

A short-lived NixOS **user** timer on ringtail that watched the Skagit
Community & Continuing Education course catalog for a new ceramics class.
Introduced 2026-08-11, retired 2026-09-01 after it succeeded: on
2026-09-01 it caught a new ceramics class (Item Number 38826) the day the
college listed it, filed the red heph task, pushed the ntfy alert, and Erich
acted on it. Decommissioned per
[eblume/blumeops#779](https://forge.eblu.me/eblume/blumeops/issues/779). This
doc is the persistent record of what it was and the AAR.

## What it was

A systemd **user** timer (`skagit-cce-watch`, every 5 minutes) running a
stdlib-only Python script:

- scrapes the Skagit CCE course catalog category page (public ASPX,
  campusce.net)
- diffs catalog Item Numbers against a baseline state file
- on a new ceramics-sounding title: files a **red** heph task under the
  Ceramics project (course link in the task's context) plus a best-effort ntfy
  push to the self-hosted ntfy's `ceramics` topic (`X-Click` opens the course
  page)

Timeline:

- 2026-08-11: introduced (hourly cadence) — blumeops PR #593
- 2026-08-13: cadence raised to every 5 minutes; ntfy push added (heph task
  01M098EQ1PVFB1A56BD0MSEANC)
- 2026-09-01: it fired — red task "New ceramics class: Ceramics (item 38826)"
  (heph 01M1EWASKR5M3CDG0HZD2V3J2J), first seen 2026-09-01
- 2026-09-01: Erich acted; requested retirement + AAR (eblume/blumeops#779)

## AAR — what worked

- The red heph task was the primary alert and it landed in the agenda: the
  college lists classes without notice, and we caught this one day one.
- The two-channel design did its job: the ntfy push reached the phone with a
  tappable course link; a push failure was never allowed to fail the tick.
- The defensive details paid off through ~3 weeks of operation — first run
  baselines silently, a zero-course parse fails loudly instead of wiping
  state, and the item-number keying prevented duplicate alerts. No false
  alerts, no state loss.

Caveat, honestly logged: the alert took ~45 minutes to get noticed. The ntfy
push used the default iOS alert sound, and the red task waited for the next
agenda pass. If the watch returns in a broader form, make the alert harder to
ignore — a distinct ntfy sound for the topic (ntfy's iOS app allows per-topic
sound settings) or a repeat until acknowledged.

## The pattern (if it returns in broader form)

The general pattern: poll a public catalog/feed → diff on a stable item id →
title-match → file a red heph task (+ best-effort ntfy push). The building
blocks: a systemd **user** timer/oneshot (user scope so `heph` can reach
eblume's spoke over `XDG_RUNTIME_DIR`), stdlib-only Python, a baseline state
file, silent first run, fail-loud-on-empty-parse, and a loose regex net for
the title match. The watch code itself is in git history
(`nixos/ringtail/skagit-cce-watch.{nix,py}`, PR #593) and is a usable starting
point.

## Decommission

No ArgoCD involvement: this was a NixOS *user* unit, and ArgoCD only manages
ringtail's k8s workloads — the host's NixOS is provisioned out-of-band by the
ansible playbook.

Repo side (this PR): deleted `nixos/ringtail/skagit-cce-watch.{nix,py}`,
removed the import from `nixos/ringtail/configuration.nix`, replaced the
reference-card section with a pointer to this doc.

Host side (one-time, after the merge): `mise run provision-ringtail` (from
gilbert) syncs blumeops to ringtail's `/etc/blumeops` and runs
`nixos-rebuild switch --flake /etc/blumeops/nixos/ringtail#ringtail`; the
activation prunes `skagit-cce-watch.{service,timer}`. Once the
`ringtail-rebuild` warrant has merged and this one manual `provision-ringtail`
has activated its sudo grant, later rebuilds of that shape can instead be
requested: `mise run request-run ringtail-rebuild.yaml <sha> -i revision=<sha>
--why "apply the skagit-cce-watch retirement"`. Verify
`systemctl --user list-timers | grep skagit` (as eblume) comes back empty.
Optional: `rm -rf ~/.local/state/skagit-cce-watch` (baseline state file).
ntfy: nothing server-side (the topic was client-side only); remove the
`ceramics` subscription on any phone if desired. heph: the Ceramics project
and the success task 01M1EWASKR5M3CDG0HZD2V3J2J stay as the record.
