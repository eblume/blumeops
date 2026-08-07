Install `actionlint` and `stylua` on the Forgejo runner. prek downloads the
environment for most hooks, but a `*-system` hook runs whatever is on `PATH` by
definition — and a missing binary is reported as a **failed** hook, not a skipped
one. Two consequences had been sitting unnoticed:

- blumeops' own `actionlint-system` hook has never linted a workflow. It would
  have been failing anyway: `.github/actionlint.yaml` was missing the `indri` and
  `priv` labels, which made 10 of 12 workflows unlintable (fixed separately).
- `hephaestus.nvim`'s CI has its `prek run --all-files` step stubbed out with an
  `echo`, blamed on a runner without prek. prek has been installed for a while;
  what actually still blocked the restore was `stylua` and `actionlint`.

The runner reference card also listed a toolchain that was never accurate — it
advertised a `jq` the role does not install. It now points at
`forgejo_runner_host_tools` as the source of truth rather than restating it.
