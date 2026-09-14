Daily service review: teslamate (argocd, last reviewed 2026-06-03). Bumped
the Nix build from v3.0.0 to v4.2.0 (latest release, 2026-08-23) — a full
train jump, eblume-approved on [eblume/blumeops#1083](https://forge.eblu.me/eblume/blumeops/issues/1083):
changelog v3.1.0→v4.2.0 reviewed release by release, no breaking change in
the span applies to this deployment. Build moves erlang_27/elixir_1_18 →
erlang_28/elixir_1_19 (v4.1.0+ requires elixir ~> 1.19) and drops the
ex_cldr locale pre-fetch (replaced upstream by localize in v4.2.0); the
Grafana dashboard fetch pin moves v3.0.0 → v4.2.0.
