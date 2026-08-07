An approved SHA now has to reach the run it approves. `warrant-policy.yaml`
gives every warrant-class action a `binds_sha` naming the dispatch input that
carries the commit, and `mise run request-run` refuses a request that omits it,
sends a different SHA, or sends a mutable ref like `main`. Previously the bound
SHA and the dispatch inputs were unrelated fields: warrant #22 approved
`bcb2b55`, dispatched with no `ref`, built main, and reported success.
`verify-runs` audits the same property afterwards — comparing the request record
against itself, never the run's `head_sha`, which is main's tip at dispatch time
— and leaves a mismatched task open instead of closing it. Request comments now
link the Warrant queue entry, and a bare `#N` in `--why` no longer autolinks to
an unrelated PR.
