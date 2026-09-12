Document the required-status-checks invariant on `main` (eblume/blumeops#1013):
the four required pull_request contexts (Docs Checks / checks plus the three
Lint jobs) are listed in docs/explanation/agent-change-process.md under "The
residual problem", and the lint.yaml header now warns that renaming a job
silently un-requires it, since the context string is the job name.
