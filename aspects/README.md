# Aspect suite

Durable instance rules, checked before merge — no agent, no human. Design:
[docs/explanation/talos-v0.5/aspects.md](../docs/explanation/talos-v0.5/aspects.md).

Run: `mise run aspects [--repo PATH] [--repo-name OWNER/NAME] [-- <pytest
args>]` (default target: this blumeops checkout). CI: the Aspects PR job
(`.forgejo/workflows/aspects.yaml`, `indri-build`), required by name on main
(`forge/branch-protections.json`).

## Adding an aspect

`aspects/<slug>/` is a Python package (`__init__.py`) with:

- `ASPECT.md` — intent (2–5 sentences), alternatives rejected, scope filters
- one `test_*.py` module exposing `KIND` (`"invariant"` | `"ratchet"`),
  `check(root: pathlib.Path) -> list[str]`, and optionally
  `APPLIES_TO: list["owner/name"]` (absent = every repo)
- `baseline.json` (ratchet only) — a JSON list of the violations allowed to
  remain; the list may only shrink
- `fixtures/red/<case>/` — each case directory is passed to `check()` and
  must be rejected
- `fixtures/green/<case>/` — each case directory is passed to `check()` and
  must be accepted

`check()` scopes itself: the fixtures live under `aspects/<slug>/` inside
the target repo, so an aspect that applies to blumeops must restrict its
scan to paths outside its own fixture tree (or use `APPLIES_TO`).

`aspects/test_meta.py` fails an aspect whose fixtures don't hold (the
red-fixture meta-test); `aspects/test_repo_scan.py` runs each aspect against
the target repo. Budgets: 10 s per test (pytest-timeout), 120 s wall clock
per repo run. Changing an aspect's rules, filters or baseline (other than
shrinking) needs eblume's go.
