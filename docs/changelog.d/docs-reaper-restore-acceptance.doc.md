Reaped-session restore runbook: single-pass borg→tar extract, and correct the claim that `kubectl cp` keeps mtime (it doesn't; the interlock skips a restored file until the next backup).
