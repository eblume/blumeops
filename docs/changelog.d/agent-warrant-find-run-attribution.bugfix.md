warrant v0.3.3: a warrant no longer names a CI run it did not cause. v0.3.2's
`_find_run` retried only while the run list was *empty*, so for any workflow
with history the first poll returned the newest **pre-existing** run —
warrants #5 and #7 each asserted a run Erich never authorized. The dispatch
now sends `return_run_info`, so the forge answers 201 naming the run it just
created and there is nothing left to infer; a dispatch that comes back without
one links the workflow's run list rather than guessing. Warrants also record
`dispatched_at`, which makes a bad link detectable after the fact. First unit
tests for the service, run with `mise run warrant-test`.
