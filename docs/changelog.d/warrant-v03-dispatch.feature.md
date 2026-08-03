Warrant v0.3.0 — approvals can execute: an approved warrant is consumed
(single-use, TTL-checked, policy re-checked against main) and its workflow
dispatched as `warrant-bot`. Ships **disabled**; `WARRANT_DISPATCH_ENABLED`
arms it separately. Approving now goes through a confirm page showing the
full input set and diff link — the list view can deny, not approve.
