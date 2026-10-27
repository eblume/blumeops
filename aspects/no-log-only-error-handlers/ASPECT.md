# no-log-only-error-handlers

Ratchet: an error handler that only logs turns a failure into silence. The
code-level cousin of the silent workflows (eblume/blumeops#1566, horkos#57).
This aspect flags a Python `except` whose body is nothing but logging calls
(`logging.*`, `logger.*`/`log.*`/`_log*`/`self.log.*` at debug..critical, or
`print`), so the handler swallows the error with no trace of a decision.

A handler passes if its body contains any statement that is not a logging call
(a `raise`, a `return`, an assignment, `continue`): that is a handled path, even
`return None`. A logging call whose arguments carry a metric increment
(`.inc(` / `.observe(`, including `.labels(...).inc()`) or an ntfy call (a callee
whose name mentions `ntfy`) passes too. Empty handlers (`pass`, `...`) are not
flagged: the rule is about handlers that *only log*, and an empty-handler rule
would be a separate aspect. A trailing `pass` after a log call is not flagged
for the same reason. Calls whose receiver is itself a call (for example
`logging.getLogger(x).error(...)`) are not recognised as logging and so are not
flagged; this is a known gap.

Test files are exempt: `test_*.py`, `*_test.py`, `conftest.py`. Every other
`.py` file is scanned, including helpers under `tests/`; the dependency and
build directories (`node_modules`, `venv`, `dist`, `build`, `__pycache__`) and
dot-directories are skipped.

The violation key is `path::<scope>#<ordinal>`: the dotted class/function path
(`<module>` at top level) and the handler's index among the scope's *log-only*
handlers, in source order. Line numbers would churn the baseline on every edit
above a handler. The ordinal counts only log-only handlers, so adding a handler
that does something other than log does not rename a baselined one; adding a
log-only handler above one does.

**Scope.** `APPLIES_TO = ["eblume/horkos"]`: the Python side only. The
TypeScript `catch` side is `no-log-only-catch-typescript` (talos). `baseline.json`
is horkos's violations at upstream/main; it may only shrink. The matcher is
tree-sitter (`tree-sitter-python`, pinned in the suite's `uv run --script`
header), not semgrep.
