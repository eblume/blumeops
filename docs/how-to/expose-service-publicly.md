---
title: Expose a Service Publicly
tags:
  - how-to
  - cloudflare
  - networking
---

# Expose a Service Publicly via Cloudflare Tunnel

> **Status:** Plan — not yet implemented. Execute phases in order when ready.

This guide describes how to expose a BlumeOps service to the public internet securely using Cloudflare as a CDN and DDoS shield, with a Cloudflare Tunnel creating an outbound-only connection that never exposes the home IP.

The first service to expose is `docs.eblu.me`. The pattern is reusable for future services.

## Architecture

```
Internet → docs.eblu.me (Cloudflare proxied CNAME)
               │
         Cloudflare Edge (CDN, WAF, DDoS protection)
               │
         Cloudflare Tunnel (outbound from k8s)
               │
         cloudflared pod in minikube
               │
         docs k8s Service (ClusterIP, port 80)
               │
         docs pod (nginx + Quartz static site)

Tailnet → *.ops.eblu.me (unchanged, DNS-only to Tailscale IP)
```

All existing `*.ops.eblu.me` services remain private behind Tailscale. Only explicitly configured subdomains (like `docs.eblu.me`) are exposed publicly through Cloudflare.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| DNS hosting | Move from [[gandi]] to Cloudflare (free) | CNAME/partial setup needs Business plan @ $200/mo |
| Gandi role | Registrar only | Domain renewal, WHOIS. No more DNS hosting. |
| Tunnel host | Kubernetes | ArgoCD managed, direct ClusterIP access, no Tailscale hop |
| [[caddy]] TLS | Migrate to Cloudflare DNS-01 plugin | Gandi DNS-01 won't work after nameserver change |
| Cloudflare account | Recover existing, instrument with IaC | |

## Prerequisites

- Cloudflare account with `eblu.me` zone added (free plan)
- Cloudflare API token stored in 1Password with scopes: Zone:DNS:Edit, Zone:Zone:Read, Account:Cloudflare Tunnel:Edit, Account:Account Settings:Read
- Cloudflare account ID and zone ID noted

## Phase 0: Preparation (manual)

1. Recover Cloudflare account access
2. Add `eblu.me` zone (free plan) — Cloudflare scans existing records from Gandi
3. **Do not change nameservers yet** — wait until Phase 3
4. Create API token with the scopes listed above
5. Store API token and account ID in 1Password (blumeops vault)

## Phase 1: Caddy TLS migration

**Why first**: Blocking dependency for the nameserver change. Once nameservers move to Cloudflare, Gandi LiveDNS can't serve DNS-01 ACME challenges.

### Caddy binary rebuild

Rebuild Caddy with `github.com/caddy-dns/cloudflare` instead of `github.com/caddy-dns/gandi` using `xcaddy` in `~/code/3rd/caddy/`.

### Files to modify

- `ansible/roles/caddy/templates/Caddyfile.j2` — change `dns gandi {env.GANDI_BEARER_TOKEN}` to `dns cloudflare {env.CF_API_TOKEN}`
- `ansible/roles/caddy/templates/caddy-wrapper.sh.j2` — source Cloudflare API token instead of Gandi PAT
- `ansible/roles/caddy/defaults/main.yml` — update token variable name
- `ansible/playbooks/indri.yml` — add pre_task to fetch Cloudflare API token from 1Password, replace Gandi PAT fetch

### Deployment sequence

1. Set up Cloudflare zone with all records (Phase 2)
2. Prepare Caddy migration on a branch (this phase)
3. Change nameservers at Gandi (Phase 3)
4. Immediately deploy Caddy update: `mise run provision-indri -- --tags caddy`
5. Caddy's next TLS renewal uses Cloudflare DNS-01

Existing certificates are valid for ~90 days, providing a grace window.

## Phase 2: Pulumi — Cloudflare IaC

Create a new Pulumi project at `pulumi/cloudflare/`.

### Files to create

- `pulumi/cloudflare/Pulumi.yaml` — project definition (`blumeops-cloudflare`, python/uv)
- `pulumi/cloudflare/Pulumi.eblu-me.yaml` — stack config (domain, account-id)
- `pulumi/cloudflare/pyproject.toml` — deps: `pulumi>=3.0.0`, `pulumi-cloudflare>=5.0.0`
- `pulumi/cloudflare/__main__.py`

### Pulumi program manages

- Zone lookup for `eblu.me`
- DNS records:
  - `*.ops.eblu.me` A record → Tailscale IP, **proxied=False** (grey cloud, private)
  - `ops.eblu.me` A record → Tailscale IP, **proxied=False**
  - `docs.eblu.me` CNAME → `<tunnel-id>.cfargotunnel.com`, **proxied=True** (orange cloud, CDN)
- Cloudflare Tunnel resource
- Tunnel config (ingress: `docs.eblu.me` → `http://docs.docs.svc.cluster.local:80`)
- Cache rules for static docs site (edge TTL: 1 day, browser TTL: 1 hour)
- Zone security settings (SSL: full, min TLS 1.2, always HTTPS)

### New mise tasks

Following the `dns-preview`/`dns-up` pattern:

- `mise-tasks/cloudflare-preview` — `pulumi preview` with 1Password token injection
- `mise-tasks/cloudflare-up` — `pulumi up` with 1Password token injection

Keep `pulumi/gandi/` until migration is confirmed working. Then `pulumi destroy` the Gandi stack and archive the code.

## Phase 3: DNS migration

### Pre-migration checklist

- [ ] Cloudflare zone active with all records (Phase 2)
- [ ] Caddy migration branch ready (Phase 1)
- [ ] Cloudflare Tunnel created and configured (Phase 2)
- [ ] cloudflared running in k8s (Phase 4)

### Steps

1. At Gandi registrar dashboard: change nameservers to Cloudflare's assigned NS
2. Deploy Caddy update immediately: `mise run provision-indri -- --tags caddy`
3. Monitor propagation: `dig +trace docs.eblu.me`, `dig +trace forge.ops.eblu.me`
4. Verify tailnet services still work from tailnet clients
5. Verify `docs.eblu.me` resolves publicly

### Rollback

Change nameservers back to Gandi's at registrar. Everything reverts.

## Phase 4: cloudflared in Kubernetes

### Files to create

- `argocd/apps/cloudflare-tunnel.yaml` — ArgoCD Application
- `argocd/manifests/cloudflare-tunnel/deployment.yaml` — cloudflared Deployment
  - Image: `cloudflare/cloudflared:latest` (or pinned version)
  - Args: `tunnel --no-autoupdate run --token <tunnel-token>`
  - Single replica, tunnel token injected from a Secret
- `argocd/manifests/cloudflare-tunnel/external-secret.yaml` — ExternalSecret to pull tunnel token from 1Password
- `argocd/manifests/cloudflare-tunnel/kustomization.yaml`

### Tunnel routing (managed by Pulumi)

- `docs.eblu.me` → `http://docs.docs.svc.cluster.local:80` (direct k8s service access)
- Catch-all → `http_status:404`

Namespace: `cloudflare-tunnel` (dedicated, reusable for future public services)

## Phase 5: Documentation and cleanup

### Files to create

- `docs/reference/infrastructure/cloudflare.md` — reference card
- `docs/changelog.d/<branch>.feature.md` — changelog fragment

### Files to modify

- `docs/reference/infrastructure/routing.md` — add public services section
- `docs/reference/infrastructure/gandi.md` — update to registrar-only role
- `docs/reference/services/docs.md` — add public URL `https://docs.eblu.me`
- `docs/reference/reference.md` — add Cloudflare to infrastructure section
- `CLAUDE.md` — update routing table, add cloudflare tasks

## Verification

1. `curl -I https://docs.eblu.me` from public internet — returns 200 with `cf-ray` header
2. `dig docs.eblu.me` — shows Cloudflare IPs (not Tailscale IP)
3. `dig forge.ops.eblu.me` — still shows `100.98.163.89` (Tailscale IP)
4. All `*.ops.eblu.me` services accessible from tailnet
5. `mise run services-check` passes
6. Caddy TLS renewal works (force test with `caddy reload` if needed)
7. Cloudflare dashboard shows tunnel healthy and cache hits

## Risks

| Risk | Mitigation |
|------|------------|
| Caddy TLS renewal fails after NS change | Deploy Caddy update immediately; existing certs valid ~90 days |
| DNS propagation delay (24-48h) | Set low TTLs before migration; monitor with `dig +trace` |
| cloudflared crashes | K8s restarts it; Cloudflare serves cached content |
| Tunnel credentials leak | 1Password + ExternalSecret; tunnel only routes to docs |

## Adding more public services

To expose another service publicly (e.g., `wiki.eblu.me`):

1. Add DNS record + tunnel ingress rule in `pulumi/cloudflare/__main__.py`
2. Run `mise run cloudflare-up`
3. No changes to cloudflared deployment (remotely-managed tunnel config)
