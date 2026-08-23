`pr-comments` now reads the full review feedback of a PR: every conversation
comment, every review (state, body, commit), and every review comment
grouped into threads per diff location, including follow-up posts. Each
comment carries its file path, commit, diff position, and hunk so feedback
pins to exact lines. Resolved threads collapse to one-line pointers by
default (`--resolved` expands them); new `--repo` and `--json` options for
other repos and machine polling.
