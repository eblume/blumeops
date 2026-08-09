Forgejo upgraded 15.0.3 → 16.0.2, and `mise run runner-logs` moved onto the
Actions job-log REST API that arrived with it. Private-repo CI logs were
unreadable outside a browser: the only log route Forgejo 15 has is a **web**
route, and Forgejo does not accept API-token auth on web routes at all — token,
`Bearer`, basic and `?token=` all leave the request anonymous, which is enough
for public `blumeops` and a 404 for every private repo. v16's
`/repos/{owner}/{repo}/actions/jobs/{job_id}/logs` honours the token, so
`runner-logs` prefers it, keeps the web route as a pre-upgrade fallback, and now
says which of the two failed and why instead of "no log available".
