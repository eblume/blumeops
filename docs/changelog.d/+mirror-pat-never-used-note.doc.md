[[manage-forgejo-mirrors]]: document that the old GitHub fine-grained PAT
shows "Last used: never" even after weeks of active syncing (last-used
tracking is unreliable for git-over-HTTPS), and add a `rate_limit` auth check
as the reliable way to verify a rotated mirror PAT.
