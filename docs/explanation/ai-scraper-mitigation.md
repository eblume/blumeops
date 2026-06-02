---
title: AI Scraper Mitigation
modified: 2026-06-01
last-reviewed: 2026-06-01
tags:
  - explanation
  - fly-io
  - forgejo
  - security
  - networking
---

# AI Scraper Mitigation on the Public Proxy

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words — these serve as placeholders to establish the documentation structure.

How BlumeOps keeps AI crawlers from running up the [[expose-service-publicly|Fly.io proxy]] egress bill and DoS-ing [[forgejo|Forgejo]] on [[indri]].

## The incident

A $29.60 Fly.io invoice arrived, nearly all of it a single line:

```
Bandwidth: Egress (iad) — 958,524,714,138 bytes — $19.17
```

The `iad` (Ashburn) region is a red herring: the proxy machine runs in `sjc`,
but Fly bills egress at the edge PoP nearest the *client*, so `iad` just means
"the traffic went to clients on the US East Coast."

Tracing it through the nginx access logs (shipped to Loki via [[alloy|Alloy]]):

| Signal | Value |
|--------|-------|
| Total proxy egress (30d) | ~1.25 TB |
| Share that was `forge.eblu.me` | **99.95%** |
| Share of forge egress that was `/mirrors/*` | **~71%** |
| Share that was declared AI bots | **~85%+** |
| Top offenders | Meta `meta-externalagent` (66% of bytes), OpenAI `GPTBot` (16%), Amazonbot, Bytespider |
| Forgejo `5xx` (upstream timeouts) | tens of thousands/day, spiking to 112k |

The crawlers were walking [[forgejo|Forgejo]]'s git-history browse endpoints —
`src/commit/<sha>`, `commits/`, `blame/`, `raw/commit/`, plus `.patch`/`.diff`
and `?page=N` pagination. That URL space is effectively **infinite**: every
file × every commit × every page, multiplied across every mirrored repo. A
crawler that follows links never finishes, and every page is a cache `MISS`
that both tunnels to indri *and* bills as egress.

Two distinct harms, not one:

1. **Cost** — ~1.25 TB/mo of egress on a free-tier-ish proxy.
2. **Availability** — the crawl alone generates ~400–530k requests/day,
   enough to time out Forgejo regardless of how much RAM [[indri]] has. Moving
   egress elsewhere would *not* fix this; the crawl has to be throttled at the
   source.

`robots.txt` already `Disallow`s `/mirrors/`, `/user/`, and archive/download
paths — but **`meta-externalagent` and `GPTBot` ignore it.** For these agents,
`robots.txt` is a dead letter, which is why edge enforcement is required.

## The tiered plan

### Tier 1 — Black-hole `/mirrors/*` (shipped)

The mirror repositories (`tailscale`, `prometheus`, `mealie`, `paperless-ngx`,
…) are mirrors of *already-public upstreams*, kept for supply-chain control
(see [[spork-strategy]] and the container/mirror story in [[why-gitops]]). They
are consumed by CI, gilbert, and other tailnet clients over
`forge.ops.eblu.me`. Their web UI on the public internet served **no
legitimate audience** — only scrapers. So the proxy now returns `403` for
anything under `/mirrors/`, pointing humans at the tailnet host:

```nginx
location ^~ /mirrors/ {
    return 403 "Mirror repositories are tailnet-only — use forge.ops.eblu.me.\n";
}
```

The `^~` modifier matters: without it, the regex `location` blocks for static
assets (`*.css`, `*.js`, release downloads) would match first and leak content
under `/mirrors/`. `^~` tells nginx to stop at the prefix match and skip the
regex round.

This is config, not bot-fighting — we simply stopped serving an infinite
tarpit to the world. It removes ~71% of forge egress and a large share of the
upstream timeouts, with zero impact on any human or tailnet consumer. It
mirrors the existing tailnet-only blocks for `/api/packages/` and `/swagger`.

The `403` is also a small act of public shaming. Blocked requests are served a
"roll of dishonour" page (`fly/naughty.html`, status kept at `403` via
`error_page 403 /naughty.html`) that names the offending operators and their
share of the stolen bytes, and every response carries an `X-Naughty-Scrapers`
header:

```
X-Naughty-Scrapers: OpenAI/GPTBot, Meta/meta-externalagent, Amazonbot, ByteDance/Bytespider — robots.txt ignorers
```

Petty? A little. But it costs nothing, documents *why* the block exists for the
next person who hits it, and the page is a few KB versus the megabytes of git
HTML the crawlers were taking.

**Trade-off accepted:** mirror release-artifact downloads over WAN now also
`403`. Legitimate consumers already pull these over the tailnet, and the public
exposure was the same crawl liability, so this is intentional.

### Tier 2 — Defend the repos that *stay* public (planned)

`/eblume/*` is intentionally public (a public profile is a feature). But the
same git-history endpoints are still a tarpit there, just lower-volume. Two
layers, in increasing order of effort and effectiveness:

#### 2a. User-agent denylist (cheap, evadable)

Block the declared AI crawlers at the edge regardless of path:

```nginx
# Illustrative — not yet deployed.
map $http_user_agent $is_ai_bot {
    default                 0;
    "~*meta-externalagent"  1;
    "~*GPTBot"              1;
    "~*ClaudeBot"          1;
    "~*Amazonbot"          1;
    "~*Bytespider"         1;
    "~*SemrushBot"         1;
}
# in the forge.eblu.me server block:
if ($is_ai_bot) { return 403; }
```

This catches ~85% of *current* traffic for a few lines of config. It is
trivially evadable — a scraper need only spoof a browser UA — so it is a
speed-bump, not a wall. Keep `robots.txt` too: well-behaved crawlers
(Googlebot, Bingbot) do honor it, and it documents intent.

#### 2b. Anubis proof-of-work gateway (the real wall)

[Anubis](https://github.com/TecharoHQ/anubis) is a Go reverse proxy that
weighs each request with a browser-based proof-of-work challenge before passing
it upstream. It was written for *exactly this scenario* — its author built it
after Amazon's scraper took down their Git server — and is widely deployed in
front of Forgejo/Gitea (Codeberg, the UN, etc.). Headless scrapers that can't
run the challenge JS never reach the application; humans clear it once and
proceed.

Why it fits BlumeOps better than the alternatives:

- **It attacks cost *and* availability at once.** Bots receive a few-KB
  challenge page instead of MB of git HTML (egress collapses) and never reach
  Forgejo (timeouts collapse). No other single lever does both.
- **It stays in-house.** No third party terminates our TLS or sees our
  traffic.

Placement options:

| Where | Pros | Cons |
|-------|------|------|
| On [[indri]], between [[caddy|Caddy]] and Forgejo | Protects every path and every entry (WAN *and* tailnet); one config | Adds a hop and a service to the indri critical path; the challenge page still tunnels back through Fly for WAN clients (small egress) |
| On the Fly proxy machine, in front of nginx | Challenge served at the edge — bots never even tunnel to indri | Fly VM is small (512 MB); another moving part in the boot sequence alongside `tailscaled`/nginx/`fail2ban`/Alloy |

Leaning toward Caddy-side on indri for simplicity and uniform coverage, but
this is the open design question for Tier 2. Anubis is MIT-licensed and the
author has signalled a future move to an `equi-x`-based challenge, so pin a
version and track upstream.

### Tier 3 — Move egress off Fly entirely (rejected)

A [[#The incident|Cloudflare]] Tunnel (`cloudflared` on indri → Cloudflare
edge) would make this a non-problem on the cost axis: Cloudflare does not meter
proxied bandwidth, and it bundles free AI-bot mitigation (Bot Fight Mode, the
"block AI scrapers" toggle, Managed Challenge, AI Labyrinth). One move would
zero the egress bill and add bot defense.

**We are not doing this, on principle.** Cloudflare is a solid platform and a
defensible engineering choice — but it already sits in front of an enormous
fraction of the modern web, and routing BlumeOps through it would add one more
site to the pile of the internet that one company can see and gate. BlumeOps
deliberately keeps its own backbone ([[expose-service-publicly|Fly + Tailscale
+ Caddy]], DNS at [[gandi|Gandi]] — see the "no Cloudflare dependency" line in
that doc). This is a values decision, not a technical one: we would rather pay
a few dollars and run our own mitigation than centralize on Cloudflare.

It is also worth noting that **Tier 3 would not, by itself, fix the upstream
timeouts** — free egress just means we'd stop *caring* that bots crawl, while
they continued to hammer Forgejo. Crawl mitigation (Tier 1 + Tier 2) is
required regardless of where egress is billed.

## Summary

| Tier | Lever | Cost | Availability | Status |
|------|-------|------|--------------|--------|
| 1 | Black-hole `/mirrors/*` at edge | −~71% | big drop | **shipped** |
| 2a | UA denylist on remaining repos | −most of the rest | further drop | planned |
| 2b | Anubis PoW gateway | −near-total | near-total | planned |
| 3 | Cloudflare Tunnel | −total | needs 2b anyway | **rejected (principle)** |

The guiding insight: the cheapest, lowest-risk mitigation is to **not serve an
infinite-URL surface that has no human audience.** Everything past Tier 1 is
about defending the surface we *do* want public, in-house, without ceding
control of our traffic to a third party.
