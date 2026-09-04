`mise run verify-runs` no longer guesses a run for a warrant record that
carries no `run_number` — it reports, and refuses inference for, three
states: request status `dispatched` without a run number means the dispatch
ran but the forge never named a run (pre-`return_run_info` forge / 204) —
reported **dispatched-norun** and left for a human to link or re-dispatch;
request status `dispatch_failed` means the dispatch attempt failed (the
warrant note carries the reason) — reported and left open; any other run-less
status (approved / denied / superseded) was **never dispatched**, with the
warrant note's `not dispatched: {reason}` surfaced when horkos recorded one
(eblume/horkos#13). The forge-side run heuristic stays reserved for approvals
with no warrant record at all — pre-stamp tasks or a warrant outage. Fixes
the eblume/horkos#12 misattribution, where request #54 — approved, never
dispatched (warrant `consumed=0`, `run_number=null`) — was closed against
run 1754, which belonged to a different request.
