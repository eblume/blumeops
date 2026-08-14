Stop zot's Trivy DB downloads from poisoning log shipping. The CVE extension
downloads trivy-db (~90MiB) and trivy-java-db (~900MiB) daily with trivy's
progress bar enabled — zot hardcodes `quiet=false`, no config knob — and under
launchd's file redirection the carriage-return animation frames of one download
pile up into a single newline-less line of up to 3.7MB. Loki rejects any entry
over its 256KB limit with a 400 that fails the whole batch, which is how
`mcquack.zot.err.log` shipped zero lines despite being actively written (the
zot.err half of the indri log-shipping audit): only 9 of the file's 37k lines
were progress bars, but they wedged alloy's position tracking and dragged the
normal lines down with them.

Three layers, in order of the pipeline:

- The zot LaunchAgent now starts via a wrapper (`zot-serve.sh`) that passes
  stderr through an awk filter which splits physical lines on CR and drops the
  bar frames, keeping any real content that shares the line. stdout is
  untouched.
- A one-time idempotent task truncates the polluted stderr log (its real
  content is already in Loki; the bar frames are unshippable), which also
  resets alloy's saved tail position — parked mid-file at the end of the first
  giant line — via truncation detection.
- The alloy role gains a `loki.process` guard that drops any line over 255KB
  from any tailed service instead of letting it fail the batch, counted in
  `loki_process_dropped_lines_total{reason="line_too_long"}`.
