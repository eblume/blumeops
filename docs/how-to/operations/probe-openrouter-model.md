---
title: Probe an OpenRouter Model's Providers
modified: 2026-09-12
tags:
  - how-to
  - operations
  - ai
---

# Probe an OpenRouter Model's Providers

`mise run openrouter-probe` fires chat completions pinned to each provider
serving a model and reports, per provider: whether `reasoning.effort` moves
reasoning-token counts (low/high/max sweep), how often a completion comes back
empty (HTTP 200 with no content and no tool call), p50/p95 latency, and
error/429 rates.

## When to run it

- Before adding a model to the [[talos]] model menu — effort sensitivity is
  what decides whether a cheap `low`-effort setting is usable for a reasoning
  model.
- When a model's error or empty-completion rate starts moving — a bump in the
  `err` or `empty` columns tells you whether the problem is one provider or
  all of them.

## Why run it from a talos session

OpenRouter providers rate-limit by IP, so a result from a laptop is not a prod
result. Run the probe from a talos session so egress is the pod's; the tool
prints an egress banner (proxy and source IP) and the key source (`env` or
`op`) before any call, so a result is never misattributed to the wrong
environment.

## Probe a model

```fish
mise run openrouter-probe deepseek/deepseek-v4-flash-0731 --reps 2
```

The `re low`/`re high`/`re max` columns are the median reasoning-token counts
at each effort; `err` and `429` count failed and rate-limited calls; `p50 ms`
and `p95 ms` are latency percentiles; `empty` is the share of HTTP-200 calls
that came back with no content and no tool call. In `--empty-check` mode (one
fixed `--effort`, no sweep) the reasoning columns are blank and the `empty`
share is the point.

The `tag` column is the provider string to put on a per-model provider
`ignore` list in [[talos]] — see
[eblume/talos#183](https://forge.ops.eblu.me/eblume/talos/issues/183) for that
list and [eblume/talos#181](https://forge.ops.eblu.me/eblume/talos/issues/181)
for the provider label it compares against. See [[talos-design]] for how
providers are routed.

Records land in `./openrouter-probe-<model>-<timestamp>.jsonl`, or stream to
stdout with `--json` (the summary table goes to stderr either way).

## Previous runs

Results banked from talos sessions: [[openrouter-provider-probes]] (one section per model, newest run on top).
