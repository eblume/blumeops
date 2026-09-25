Retired indri's caddy xcaddy checkout build inputs: the role's
`caddy_repo_dir`/`caddy_checkout_binary` vars and the mise.toml-kept
special-case comment are gone, `docs/how-to/deployment/build-caddy-with-plugins.md`
is deleted, and the rollback re-run is now gate-only
(`-e caddy_ansible_managed=true` — the wrapper follows the rolled-back
generation's profile). No runtime behavior change. Part of
eblume/blumeops#1275 / eblume/blumeops#1213.
