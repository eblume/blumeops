# no-log-only-catch-typescript

Ratchet: a `catch` that only logs turns a failure into silence. The TypeScript
sibling of `no-log-only-error-handlers` (eblume/blumeops#1566, horkos#57). This
aspect flags a TypeScript `catch` whose body is nothing but logging calls
(`console.log/info/warn/error/debug/trace`, or `logger`/`log`/`_log`/`_logger`
and the same names as a trailing property, such as `this.logger.error(...)`,
with a method of debug, info, warn, warning, error, exception, critical, log or
trace), so the handler swallows the error with no trace of a decision.

A handler passes if its body contains any statement that is not a logging call
(a `throw`, a `return`, an assignment, a call to something else): that is a
handled path, even `return undefined`. Such a body is not log-only, so it is
never flagged in the first place; a `throw`/`return` in an `if` is one example.
The only `throw`/`return` (and metric or ntfy call) the matcher looks for is
inside a log-only body, which means inside the arguments of a logging call, for
example `console.error(() => { throw e; })`. A call whose metric increment
(`.inc(` / `.observe(`, including `.labels({...}).inc()`) or an ntfy call (a
callee whose text contains `ntfy`, case-insensitively) passes as well. Empty
handlers (`catch {}`) are not flagged: the rule is about handlers that *only
log*, and an empty-handler rule would be a separate aspect. A comment-only
handler has no logging call and is not flagged for the same reason.

Receiver matching is case-insensitive for the logger names (`this.LOGGER.error`
is recognised). `console` and the method names are matched exactly
(`CONSOLE.error` and `console.ERROR` are not).

**Known gaps.** These are false negatives: the matcher does not flag them.

- Logging calls whose receiver is itself a call (for example
  `getLogger(x).error(...)`) are not recognised as logging.
- `await console.error(e)` is an `await_expression`, not a bare call, so it is
  not recognised as a logging call and is not flagged.
- A class-field arrow handler (`handle = () => { try … }` in a class body) takes
  the enclosing scope (the class name), not a per-field name: the field is not a
  scope of its own.

Test files are exempt: `*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`,
`*.d.ts`. Every other `.ts` and `.tsx` file under the repo is scanned. The
dependency and build directories (`node_modules`, `dist`, `build`, `coverage`)
and dot-directories are skipped, and so is the top-level `aspects/` tree, which
holds this suite's own fixtures.

The violation key is `path::<scope>#<ordinal>`: the path is repo-relative with
forward slashes. The scope is the dot-joined names of the enclosing function,
class and method declarations, and of a variable binding (`const`/`let`/`var`)
whose value is an arrow or function expression, by its binding name; `<module>`
at top level. The ordinal is the handler's index among the scope's *log-only*
catches, in source order. Line numbers would churn the baseline on every edit
above a handler. The ordinal counts only log-only catches, so adding a catch
that does something other than log does not rename a baselined one; adding a
log-only catch above one does.

**Scope.** `APPLIES_TO = ["eblume/talos"]`: TypeScript `catch` only. The Python
side is `no-log-only-error-handlers` (horkos). `baseline.json` is talos's
violations at upstream/main; it may only shrink. The matcher is tree-sitter
(`tree-sitter-typescript`, pinned in the suite's `uv run --script` header), not
semgrep.
