New `.forgejo/CODEOWNERS` requests review from `eblume` on every PR, so an
agent-opened one lands in the "Review requests" filter rather than in no queue
at all. It is a notification, not a merge gate, and unlike a workflow it costs
no runner job per PR. Same file is going into every agent-ws repo.
