---
title: Migrate Forgejo from Brew to Source Build
status: active
modified: 2026-03-04
tags:
  - how-to
  - forgejo
---

# Migrate Forgejo from Brew to Source Build

Transition Forgejo on indri from Homebrew to a source-built binary with LaunchAgent, matching the pattern used by [[zot]], [[caddy]], and [[alloy]].

## Motivation

Forgejo was force-upgraded from v13 to v14 by `brew upgrade`, breaking version control. A source build pins versions and aligns with the established native service pattern.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Source remote** | Codeberg upstream | Avoids circular dependency (Forgejo hosting its own source) |
| **Secondary remote** | `forge.eblu.me/mirrors/forgejo` | Convenience and backup |
| **Version tracking** | `indri-deployment` branch on tag | Rebase to upgrade; explicit version pinning |
| **Build deps** | Go 1.24+, Node 20+ via mise | Consistent with other mise-managed tooling |
| **Process manager** | LaunchAgent plist | Matches zot, caddy, alloy |
| **Data location** | `~/forgejo` | Migrated from `/opt/homebrew/var/forgejo` |
| **Run user** | `erichblume` | LaunchAgent session user (SSH git user stays `forgejo`) |

## Key Steps

1. Clone from Codeberg, add forge mirror remote
2. Check out target tag, create `indri-deployment` branch
3. Build with `TAGS="bindata timedzdata sqlite sqlite_unlock_notify" mise x -- make build`
4. Stop brew service, copy data to `~/forgejo`, fix ownership
5. Run Ansible (`--tags forgejo`) to deploy updated role with LaunchAgent
6. Verify (API version, SSH clone, push, Actions runners, services-check)
7. `brew uninstall forgejo`

## Reference Patterns

- `ansible/roles/zot/` — primary pattern for source-built binary roles (tasks, defaults, handlers, plist template)

## Related

- [[forgejo]] — Service reference
