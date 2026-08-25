Recurring service reviews now file build/deploy warrant requests themselves
instead of instructing the human to dispatch CI: fixed the stale
"ask the human to dispatch" steps in `review-services.md` (written before
Horkos request-run existed), updated the talos service-review cron prompt
to match, and added a "file it, don't recommend it" rule to AGENTS.md
§Privileged actions. Verified PR-branch (fork-head) SHAs are dispatchable
pre-merge from canonical.
