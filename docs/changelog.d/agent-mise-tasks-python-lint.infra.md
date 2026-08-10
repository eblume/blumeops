`ruff` now lints `mise-tasks/`, which it has never covered. The hooks select
`types: [python]`, and `identify` derives that tag from the shebang — it reads
`#!/usr/bin/env -S uv run --script` as the interpreter `uv`, so none of the 26
uv-script tasks were ever tagged Python and no Python hook matched them. The
directory holding most of this repo's logic was the least-linted part of it.

A third ruff pass selects the directory by path. `mise-tasks/` is mixed bash and
uv-python and ruff cannot parse the bash, so the split is `exclude_types =
["shell"]`: bash tasks carry a `shell` tag from their shebang, uv scripts are
tagged only `executable, file, text`. Nothing needs updating as tasks are added
in either language.

Turning it on found 13 issues across 7 tasks — dead imports, f-strings with no
placeholders, and one dead store in `docs-preview` where `card_file` was
assigned in both branches and never read. All fixed here; only the existence
checks that guard the not-found branch ever mattered.

**No `ruff-format` pass over `mise-tasks/`, deliberately.** The formatter
normalizes `#COMMENT` to `# COMMENT`, and mise matches its task metadata
comments without a space. Running it rewrites every `#MISE description=` and
`#MISE alias=` line, which silently empties the description column of
`mise tasks` for all 26 tasks and breaks task aliases. That takes the `[human]`
prefix with it — the marker AGENTS.md tells agents to check before reaching for
a task they cannot run. Formatting is cosmetic; that fence is not.
