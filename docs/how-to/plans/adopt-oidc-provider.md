---
title: "Plan: Adopt OIDC Identity Provider"
tags:
  - how-to
  - plans
  - security
  - oidc
---

# Plan: Adopt OIDC Identity Provider

> **Status:** Planning (design sketch — not yet ready to execute)

## Background

BlumeOps services currently handle authentication independently — ArgoCD has its own admin password, Grafana has its own login, Forgejo has local accounts, and zot has no auth at all. There is no single sign-on, no centralized user management, and no way to issue scoped API keys or service tokens from a shared identity.

Adding an OpenID Connect (OIDC) identity provider gives BlumeOps a central authentication layer. Services delegate login to the IdP, and the IdP issues tokens that carry identity and group claims. This unlocks:

- **SSO across services** — one login for Grafana, ArgoCD, Forgejo, zot, and future services
- **API keys derived from identity** — zot's API key feature requires OIDC; CI service accounts get scoped, expirable tokens tied to a real identity
- **Group-based authorization** — services can make access decisions based on IdP group claims rather than per-service user lists
- **Audit trail** — authentication events flow through one system

### Goals

- Deploy a lightweight OIDC provider on the BlumeOps infrastructure
- Configure at least one service (zot) as a relying party to validate the setup
- Establish patterns for adding future OIDC clients (Grafana, ArgoCD, Forgejo)
- Keep complexity appropriate for a single-user homelab

## Provider Comparison

| Provider | Language | Resources | UI | OIDC Maturity | Zot Integration | Notes |
|----------|----------|-----------|-----|---------------|-----------------|-------|
| **Dex** | Go | ~20-50MB RAM | None (config-driven) | Mature, purpose-built | Explicitly documented in zot examples | CNCF Sandbox; `staticPasswords` connector for single-user |
| **Authentik** | Python | ~200-300MB RAM, needs PostgreSQL + Redis | Full web UI, visual flow builder | Mature | [Proven community guide](https://integrations.goauthentik.io/infrastructure/zot/) | Best for small teams; heavier than needed for one user |
| **Authelia** | Go | ~30MB RAM | None (YAML config) | Maturing (OIDC provider still on roadmap) | [Unresolved integration issues](https://github.com/authelia/authelia/discussions/7615) | Primarily a forward-auth proxy; OIDC is secondary |
| **Keycloak** | Java | ~500MB+ RAM | Enterprise admin console | Battle-tested | Works via generic OIDC | Massive overkill for homelab |

### Recommendation: Investigate Dex First

Dex is the strongest candidate for BlumeOps:

- **Lightest footprint** — single Go binary, no database dependencies (in-memory or SQLite storage)
- **Designed for exactly this** — Dex is an OIDC provider that federates identity; it's not a full IAM suite bolted onto other things
- **Zot uses Dex in its own examples** — lowest integration risk
- **`staticPasswords` connector** — define the single `eblume` user directly in YAML config, no external user store needed
- **Future flexibility** — if SSO via GitHub or Google is ever wanted, add a connector without changing the architecture
- **CNCF project** — actively maintained, well-documented

The main trade-off is no web UI for user management — but for a single-user setup, that's a non-issue. Config changes go through the normal PR workflow.

If Dex proves insufficient during execution (e.g., missing features for a specific service integration), Authentik is the fallback — heavier but more capable.

## Architecture

```
                     Caddy (TLS termination)
                              |
               +--------------+--------------+
               |              |              |
          Browser SSO    CLI / CI       k8s services
               |              |              |
               v              v              v
         Dex (OIDC IdP)  API Keys      OIDC tokens
          issuer:        (generated     (validated by
          dex.ops.eblu.me  after OIDC    each service)
               |            login)
               v
       staticPasswords
       connector (eblume)
```

### Deployment Options

Dex can run as:

1. **k8s pod** (via ArgoCD) — follows the pattern of other BlumeOps services, gets automatic restarts, lives alongside its consumers
2. **Native on indri** (via Ansible/LaunchAgent) — follows the zot/Forgejo pattern, simpler networking

The k8s option is preferred since most OIDC consumers (Grafana, ArgoCD) are already in k8s. Evaluate during execution.

### Endpoints

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Issuer | `https://dex.ops.eblu.me` | OIDC discovery (`/.well-known/openid-configuration`) |
| Auth | `https://dex.ops.eblu.me/auth` | Browser login redirect |
| Token | `https://dex.ops.eblu.me/token` | Token exchange |
| Callback | Per-client (e.g., `https://registry.ops.eblu.me/zot/auth/callback/oidc`) | OAuth2 redirect URI |

## Dex Configuration Sketch

```yaml
issuer: https://dex.ops.eblu.me

storage:
  type: sqlite3
  config:
    file: /var/dex/dex.db

web:
  http: 0.0.0.0:5556

connectors:
  - type: local
    id: local
    name: Local

staticPasswords:
  - email: eblume@eblume.net
    hash: "<bcrypt hash>"  # generated at deploy time
    username: eblume
    userID: "<uuid>"

staticClients:
  - id: zot-registry
    name: Zot Registry
    secret: "<from 1Password>"
    redirectURIs:
      - https://registry.ops.eblu.me/zot/auth/callback/oidc

  # Future clients:
  # - id: grafana
  #   ...
  # - id: argocd
  #   ...
  # - id: forgejo
  #   ...
```

Secrets (static password hash, client secrets) are stored in 1Password and injected at deploy time — never committed to the repo.

## Planned OIDC Clients

Initial rollout targets zot only. Future services to integrate:

| Service | OIDC Support | Priority | Notes |
|---------|-------------|----------|-------|
| **Zot** | Native (`openid.providers.oidc`) | First (validates IdP) | See [[harden-zot-registry]] |
| **Grafana** | Native (`auth.generic_oauth`) | High | Currently uses default admin password |
| **ArgoCD** | Native (`oidc.config` in `argocd-cm`) | High | Currently uses local admin password |
| **Forgejo** | Native (OAuth2 provider in admin settings) | Medium | Currently uses local accounts |

## Execution Steps

1. **Choose deployment method** (k8s vs native) and set up the service
   - If k8s: create `argocd/manifests/dex/` with Deployment, Service, ConfigMap
   - If native: create `ansible/roles/dex/` following the zot pattern
   - Add Caddy reverse proxy entry for `dex.ops.eblu.me`

2. **Configure Dex**
   - Generate static password hash and client secrets
   - Store all secrets in 1Password
   - Deploy initial config with `staticPasswords` connector and zot as the first client

3. **Verify OIDC discovery**
   - `curl https://dex.ops.eblu.me/.well-known/openid-configuration` returns valid JSON
   - Issuer URL matches config

4. **Integrate first client (zot)**
   - This is covered by [[harden-zot-registry]] — configure zot's `openid.providers.oidc` to point at Dex
   - Test browser login → API key generation → CLI push flow

5. **Documentation**
   - Create `docs/reference/services/dex.md` reference card
   - Update service indexes
   - Add changelog fragment

## Verification Checklist

- [ ] Dex is running and healthy
- [ ] OIDC discovery endpoint returns valid configuration
- [ ] Browser login flow works (redirect → Dex login → redirect back)
- [ ] At least one client (zot) successfully authenticates via Dex
- [ ] Caddy proxies `dex.ops.eblu.me` correctly
- [ ] `mise run services-check` passes (if health check is added)

## Open Questions

- **Service dependency and recovery:** If Dex runs in k8s and k8s goes down, services that depend on Dex for authentication may become inaccessible — potentially including tools needed to bring k8s back up. This circular dependency **must be resolved** before execution. Options include: running Dex natively on indri (outside k8s), ensuring all critical recovery paths have break-glass credentials that bypass OIDC, or designing the system so that OIDC is additive (services fall back to local auth when the IdP is unreachable). This needs its own design pass during implementation planning.
- **Dex vs Authentik:** Dex is the starting recommendation, but evaluate during execution. If multiple services need dynamic user management or a web UI for client registration, Authentik may be worth the extra weight.
- **Storage backend:** SQLite is simplest for single-node. If Dex runs in k8s, it needs a PersistentVolume or could use the k8s CRD storage backend instead.
- **Tailscale ACL interaction:** Should the Dex endpoint be tailnet-only, or accessible from the public internet (for potential external SSO)? Start with tailnet-only.
- **Token lifetime and refresh:** Dex defaults are reasonable, but may need tuning for long-running CI jobs.

## Future Considerations

- **Additional connectors** — add GitHub or Google as upstream identity sources for SSO convenience
- **Group claims** — define groups in Dex config (e.g., `admin`, `ci`) and use them for authorization across services
- **Mutual TLS** — Dex supports mTLS for service-to-service token exchange, which could harden the CI credential path

## Reference Pattern Files

| File | Purpose |
|------|---------|
| `argocd/manifests/grafana-config/` | Example k8s service with ConfigMap-based config |
| `ansible/roles/zot/` | Example native service deployment pattern |
| `pulumi/tailscale/` | Example of secrets injection from 1Password |

## Related

- [[harden-zot-registry]] — first OIDC client (execute after this plan)
- [[zot]] — container registry reference
- [[cluster]] — k8s cluster (potential Dex host)
- [[indri]] — native service host (alternative Dex host)
