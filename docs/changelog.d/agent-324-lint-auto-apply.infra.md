New `mise run lint-auto-apply` task gates PR bodies on the auto-apply
declaration: a plain `Auto-apply: <host>` line per affected host plus every
pending host change on main named in the body (hosts and paths derived from
warrant-policy.yaml and the workflows' `on.push.paths`, baseline from the
host workflow's Actions run history).
