---
title: README
---

# BlumeOps Documentation

> **Note on naming**: The project is properly stylized as **BlumeOps**, though "blumeops" and "Blue Mops" are also commonly used interchangeably.

This directory contains documentation for BlumeOps, Erich Blume's personal infrastructure GitOps repository.

## Documentation Restructuring (In Progress)

The documentation is being restructured to follow the [Diataxis](https://diataxis.fr/) documentation framework while serving multiple audiences.

### Target Audiences

1. **Erich (owner)** - A knowledge graph/zettelkasten for quickly recalling important facts about BlumeOps infrastructure and operations.

2. **Claude/AI agents** - Memory and context enrichment for AI-assisted operations and development.

3. **New external readers** - People who want to understand "what is BlumeOps?" at a high level.

4. **Potential operators/contributors** - External readers who want to help operate, modify, or answer questions about BlumeOps, or onboard as a member.

5. **Replicators** - People who want to duplicate this approach for their own personal infrastructure operations.

### Requirements

- **Source format**: Markdown with optional YAML frontmatter
- **Editing**: Compatible with [Obsidian](https://obsidian.md) and [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim)
- **Cross-references**: Wiki-link syntax (`[[link]]`) for internal links
- **Output formats**: HTML (for web hosting) and PDF (for offline reference)
- **Changelog**: Track significant documentation changes

### Tooling

**Selected**: [Quartz](https://quartz.jzhao.xyz/) - A TypeScript-based static site generator designed for Obsidian vaults. Features wiki-link support, backlinks, graph view, and excellent Obsidian compatibility.

**Architecture**:
- **Source**: Markdown files in `docs/` with optional YAML frontmatter
- **Build**: Quartz builds static HTML/CSS/JS via Forgejo workflow
- **Release**: Built assets published as Forgejo release attachments
- **Hosting**: `quartz` container downloads release bundle on startup and serves via nginx
- **URL**: `docs.ops.eblu.me` (planned)

## Restructuring Phases

### Phase 1a: Foundation & CI (Complete)
- [x] Move existing zk cards to `docs/zk/`
- [x] Update `zk-docs` mise task for new path
- [x] Create this README with restructuring plan
- [x] Select documentation tooling (Quartz)
- [x] Create Quartz configuration (`quartz.config.ts`, `quartz.layout.ts`)
- [x] Create `quartz` container for serving static sites
- [x] Create `build-blumeops` workflow for building releases
- [x] Test the build workflow and verify release creation (v1.0.0)

**First release:** [v1.0.0](https://forge.ops.eblu.me/eblume/blumeops/releases/tag/v1.0.0)

### Phase 1b: CD & Hosting (Complete)
- [x] Build and tag `quartz` container (`mise run container-tag-and-release quartz v1.0.0`)
- [x] Create ArgoCD manifests for `docs` deployment
- [x] Add `docs.ops.eblu.me` to Caddy reverse proxy
- [x] Configure deployment with `DOCS_RELEASE_URL`
- [x] Test end-to-end: commit -> build -> release -> deploy
- [x] Set up `CHANGELOG.md` with [towncrier](https://towncrier.readthedocs.io/)
- [x] Add `docs.ops.eblu.me` link to homepage dashboard (via gethomepage.dev annotations)

**Docs URL:** https://docs.ops.eblu.me

### Phase 2: Reference (Complete)
Information-oriented technical descriptions. Built first so other docs can link to reference material.

- [x] Create `reference/` directory with index
- [x] Service reference pages (16 services: alloy, argocd, borgmatic, 1password, forgejo, grafana, jellyfin, kiwix, loki, miniflux, navidrome, postgresql, prometheus, teslamate, transmission, zot)
- [x] Infrastructure inventory (hosts, tailscale, routing)
- [x] Kubernetes reference (cluster, apps)
- [x] Storage reference (sifaka, backups)

**Reference URL:** https://docs.ops.eblu.me/reference/

### Phase 3: Tutorials
Learning-oriented content for getting started.

- [ ] Create `tutorials/` directory
- [ ] "Getting Started with BlumeOps" - What this is and how to explore it
- [ ] "Setting Up a Similar Environment" - For replicators
- [ ] "Your First Contribution" - For potential contributors

### Phase 4: How-to Guides
Task-oriented instructions for specific operations.

- [ ] Create `how-to/` directory
- [ ] Migrate operational content from zk cards
- [ ] "How to deploy a new Kubernetes service"
- [ ] "How to add a new Ansible role"
- [ ] "How to update Tailscale ACLs"
- [ ] "How to troubleshoot common issues"

### Phase 5: Explanation
Understanding-oriented discussion of concepts and decisions.

- [ ] Create `explanation/` directory
- [ ] "Why GitOps?" - Philosophy and approach
- [ ] "Architecture Overview" - How everything fits together
- [ ] "Security Model" - Tailscale, secrets management, etc.
- [ ] "Decision Log" - ADRs (Architecture Decision Records)

### Phase 6: Integration & Cleanup
- [ ] Migrate remaining useful content from `docs/zk/`
- [ ] Decide fate of zk cards (archive, delete, or keep as separate knowledge base)
- [ ] Update CLAUDE.md to reference new doc structure
- [ ] Mirror docs to GitHub Pages for public access (optional)

## Current Directory Layout

```
docs/
├── README.md          # This file
├── CHANGELOG.md       # Release changelog (built by towncrier)
├── changelog.d/       # Towncrier news fragments
├── reference/         # Information-oriented (Phase 2)
├── tutorials/         # Learning-oriented (Phase 3)
├── how-to/            # Task-oriented (Phase 4)
├── explanation/       # Understanding-oriented (Phase 5)
└── zk/                # Zettelkasten cards (temporary)
    ├── 1767747119-YCPO.md  # Main blumeops overview card
    └── ...                  # Service-specific cards and notes
```

> **Why Reference first?** Reference docs are built before tutorials and how-to guides so that learning and task-oriented content can link to authoritative technical descriptions using wiki-links (`[[reference/service-name]]`).

## Adding Changelog Entries

When making changes, add a news fragment to `docs/changelog.d/`:

```bash
# Format: <identifier>.<type>.md
# Types: feature, bugfix, infra, doc, misc
echo "Add new feature X" > docs/changelog.d/20260203-feature-x.feature.md
```

Fragments are automatically collected into CHANGELOG.md when a release is built.

## Viewing the ZK Cards

To view all BlumeOps zettelkasten cards:

```fish
mise run zk-docs
```

This displays all cards tagged with `blumeops`, starting with the main overview card.
