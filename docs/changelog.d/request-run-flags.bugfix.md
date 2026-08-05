`mise run request-run` rejected every one of its own flags, so the invocation
printed in `AGENTS.md` could not work.

Its `#USAGE` block declared the two positional args and no flags. mise validates
argv against that spec *before* the script runs, so `--pr`, `-i`, and `--why`
died at `unexpected word: --pr` — and `--` does not bypass it. The flags existed
in the typer signature below, and `./mise-tasks/request-run …` run directly
worked fine, which is presumably why it went unnoticed: the documented path was
the broken one. Found while filing the build request for agent-ws v0.14.0, which
is the first requestable action an agent has had reason to file from the pod.

Declaring the four flags fixes it. Two traps surfaced while doing so, both now
written down in the script's docstring because neither is discoverable:

- **The `#USAGE` block must be contiguous.** An ordinary comment line between
  two `#USAGE` lines truncates the spec — every later line is silently dropped,
  with no warning and no error. The first attempt at this fix put an
  explanatory comment above the new flags and reproduced the original bug
  exactly.
- **Booleans are KDL v2**, so a repeatable flag needs `var=#true`. `var=true`
  fails to parse, and mise's fallback for an unparseable spec is to forward argv
  *unvalidated* — so the broken spelling appears to work, right up until the
  spec parses again and starts enforcing.

Verified by running the documented invocation against a deliberately bogus
workflow name: it now reaches `enforce_policy` and is refused there
(`.forgejo/workflows/zz-not-a-workflow.yaml does not exist on main`) rather than
dying in the argument parser, and nothing is filed. A scan of the rest of
`mise-tasks/` found no other task with either defect.
