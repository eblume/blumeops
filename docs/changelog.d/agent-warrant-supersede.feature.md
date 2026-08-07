Warrant 0.4.0 can retire an obsoleted request. `POST
/api/requests/{id}/supersede` marks a **pending** request `superseded` and
names its replacement, and `mise run request-run … --supersedes <id>` drives
the whole loop: file the new request, retire the old one, note it on the old
PR comment, close its heph tracking task. Before this, a PR that took review
feedback left two near-identical requests in the queue with nothing to say
which was live (warrant #21/#22 on PR #525), and the only recourse was prose
in the new request's `--why`.

The route only ever reduces (invariant 4): `superseded` is not `pending`, so
no warrant can be minted and nothing can be dispatched, and it is scoped to
the caller's own undecided requests — an agent cannot retire another
identity's request or undo a human's decision.
