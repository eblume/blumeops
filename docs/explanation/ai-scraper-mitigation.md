---
title: AI Scraper Mitigation
modified: 2026-06-12
last-reviewed: 2026-06-12
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

### June 2026: the crawl moves to `/eblume/*`

Tier 1 held — `/mirrors/` traffic stayed at zero cost — but on 2026-06-10 the
crawl resurfaced one path over: a single AWS-hosted client (no declared bot
UA) walked the `/eblume/*` commit-history surface (`src/commit/<sha>/<path>`,
`blame/commit/`, `commits/commit/`) at ~5.7 req/s, each request costing
Forgejo 0.5–1.7s of git CPU. Combined with minikube's footprint, that pinned
[[indri]] at load ~19 and made Forgejo's heavier API endpoints (e.g.
`/actions/tasks`) time out entirely.

Two lessons folded into the plan:

1. **Path black-holes don't generalize.** `/eblume/*` is the surface we
   *want* public; we can't 403 our way out of an infinite URL space that
   humans also browse.
2. **UA denylists are already moot.** The June crawler declared no bot UA at
   all, so Tier 2a below would not have touched it. We skipped 2a and went
   straight to the proof-of-work gateway.

### Tier 2 — Defend the repos that *stay* public

`/eblume/*` is intentionally public (a public profile is a feature). But the
same git-history endpoints are still a tarpit there, just lower-volume. Two
layers, in increasing order of effort and effectiveness:

#### 2a. User-agent denylist (cheap, evadable — skipped)

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

**Skipped in practice:** by the time we got here (June 2026), the active
scraper declared no bot UA, so this tier would have caught nothing. Anubis's
stock policy also subsumes it (`ai-block-aggressive` denies the declared
bots), so there was no reason to ship 2a separately.

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

**Placement decision: the Fly edge.** An earlier draft of this card leaned
toward indri (between [[caddy|Caddy]] and Forgejo) for uniform coverage, but
the June incident flipped the call:

- Bots are stopped *before* the Tailscale tunnel — challenge pages are a few
  KB served at the edge, so egress and indri load collapse together.
  Indri-side placement would still tunnel every challenge through Fly, and
  adds a service to the box the [[indri]]→ringtail migration is evacuating.
- The tailnet path (`forge.ops.eblu.me`) stays completely unchallenged: CI,
  git remotes, and agents are untouched, and only WAN traffic — where the
  scrapers are — pays the toll.
- Only `forge.eblu.me` gets the gate. The static sites (docs, cv) are cached
  at the proxy and shower's guest surface is rate-limited; neither serves an
  infinite URL space.

Anubis cannot rewrite the `Host` header, and indri's Caddy routes on
`forge.ops.eblu.me` (Host *and* SNI), so Anubis sits between two nginx
contexts in the same VM — the standard "nginx sandwich":

```
WAN → Fly TLS → nginx :8080 (forge.eblu.me server block)
        cheap edge blocks first: fail2ban deny, rate limits, robots.txt,
        /mirrors/ 403, packages/swagger 403, archive redirect
      → proxy_pass http://127.0.0.1:8923          (Anubis)
      → Anubis → TARGET http://127.0.0.1:8081      (internal-only nginx vhost)
      → existing static-caching + TLS/SNI proxy to indri Caddy → Forgejo
```

The edge 403s stay in front so black-holed paths never even cost a
challenge. The internal `:8081` vhost inherits the existing per-location
config (static-asset caching, release-artifact caching, upstream SNI) — see
`fly/nginx.conf`. Nothing changes on indri; Forgejo's trusted-proxy chain is
untouched.

Configuration is the stock v1.25.0 policy (no `POLICY_FNAME`), which divides
traffic the way we want out of the box:

- git clients and API callers (non-`Mozilla` UA) → weight 0 → pass through;
  public `git clone` over HTTPS keeps working
- browsers → one JS proof-of-work interstitial, then a 7-day cookie
- declared AI crawlers (GPTBot, meta-externalagent, Amazonbot, Bytespider …)
  → denied outright
- caveat: the GeoIP/ASN weighting rules require Techaro's Thoth service, so
  they are inert here; UA-based rules carry the load

Operational details: the binary is copied from the upstream container image
(pinned by digest, same idiom as tailscaled/Alloy in `fly/Dockerfile`);
`ED25519_PRIVATE_KEY_HEX` is a Fly secret (stored in 1Password) so challenge
cookies survive deploys; Prometheus metrics are served on
`127.0.0.1:9091` and scraped by the embedded Alloy. Anubis is MIT-licensed
and the author has signalled a future move to an `equi-x`-based challenge, so
the version is pinned (tracked as `flyio-anubis` in `service-versions.yaml`)
and upstream is worth watching.

#### 2c. Edge UA deny ahead of Anubis (cost optimization)

A day after Anubis shipped, a declared-bot storm (2026-06-11 PM) peaked at
~170 req/s — ClaudeBot, GPTBot, Amazonbot, Bytespider, and Alibaba-cloud
clients hammering the same git-history URLs. Anubis denied everything
(availability held on the Forgejo side), but the **proxy VM itself**
(shared-cpu-1x, 512MB) saturated serving the rejections, timing out public
`forge.eblu.me` while the tailnet path stayed healthy.

The 2026-06-12 review of the surge found:

- ~987k requests/day to `forge.eblu.me`; **746k Anubis DENYs** and ~274k
  nginx edge 403s (mostly `/mirrors/`). Challenges issued: ~11k/day,
  validated: ~124 (≈1% — challenged clients are almost all headless).
  Only **~1.3k requests/day** actually reach Forgejo from WAN.
- Egress collapsed from 14–71 GB/day pre-Anubis to ~2.5 GB/day — but
  **>99% of the remaining egress is bot-rejection bytes**: Anubis's deny
  page is ~2.4 KB of HTML (served as HTTP 200) and the `/mirrors/`
  naughty page is ~2.7 KB, each multiplied by hundreds of thousands of
  requests per day.
- The offenders are overwhelmingly *declared* bots: ClaudeBot (524k/day),
  meta-externalagent (195k/day, almost all still grinding `/mirrors/`
  403s), GPTBot (148k/day), Amazonbot (16k/day) — ~88% of all traffic,
  UA-identifiable, and already unconditionally denied by Anubis.

So Tier 2a comes back from the dead — not as a security layer (it is still
trivially evadable) but as a **cost optimization in front of Anubis**: a
`map $http_user_agent $deny_bot` in nginx returns a bare ~60-byte 403 to the
declared crawlers before the request ever reaches the Anubis proxy hop. No
Go proxy round-trip, no 2.4 KB HTML page, no `/mirrors/` naughty page for
bots (the roll of dishonour remains for human visitors). Anubis stays
exactly as configured — any bot that spoofs a browser UA to evade the map
lands on the proof-of-work wall as before. Defense in depth, with the cheap
check first.

Consequences accepted:

- Listed bots can no longer fetch `robots.txt` (the server-level `return`
  fires before location matching). These are precisely the agents that
  ignore it, so nothing of value is lost.
- `facebookexternalhit` (link previews) is deliberately **not** on the
  list — only `meta-externalagent` (Meta's AI trainer).
- The machine stays shared-cpu-1x/512MB. With denies short-circuited at
  nginx, the per-request cost under a storm drops enough that a size bump
  is not warranted; revisit if saturation recurs.

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
| 2a | UA denylist on remaining repos | −most of the rest | further drop | skipped as security (moot); revived as 2c |
| 2b | Anubis PoW gateway | −near-total | near-total | **shipped** |
| 2c | Edge UA deny ahead of Anubis | −rejection-page egress | protects proxy VM under storms | **shipped** |
| 3 | Cloudflare Tunnel | −total | needs 2b anyway | **rejected (principle)** |

The guiding insight: the cheapest, lowest-risk mitigation is to **not serve an
infinite-URL surface that has no human audience.** Everything past Tier 1 is
about defending the surface we *do* want public, in-house, without ceding
control of our traffic to a third party.
