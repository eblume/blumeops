New `mise run lint-auto-apply` task gates PR bodies on the auto-apply
declaration: a plain `Auto-apply: <host>` line per affected host plus every
pending host change on main named inside that host's blockquote block
(hosts and paths derived from warrant-policy.yaml and the workflows'
`on.push.paths`, baseline from the host workflow's Actions run history).
The derivation fails closed (a `class: auto` workflow must list a host glob
or be allowlisted), and it runs in CI as the `Lint / auto-apply` job on
every PR. The ringtail and indri auto-apply workflows now also trigger on
the shared forge-runner inputs `forge/runners.nix` / `forge/runners.json`,
which their configs import — a change there is a host change, so it gets
applied (and declared) instead of piling up on main.
