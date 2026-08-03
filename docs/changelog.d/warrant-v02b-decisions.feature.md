Warrant v0.2b — decisions and warrants: authenticated approvers
approve/deny from the UI (CSRF-guarded forms) or JSON API; approval mints
a single-use, TTL'd **warrant** binding the frozen {action, sha, inputs}
(invariants 2 & 5). Still dispatches nothing — execution stays forge-side
until v0.2c consumes warrants.
