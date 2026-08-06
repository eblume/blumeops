`mise run agent-health` now names the instance behind a firing or pending
alert, not just the rule: the distinguishing labels (`file=…`, `camera_name=…`,
`namespace=…`) plus how long it has been in that state. Grafana was already
returning them and the task discarded them, so a report said "TextfileStale is
pending" when it could have said which textfile — the first question every
runbook asks. `--json` carries the full label set per live instance.
