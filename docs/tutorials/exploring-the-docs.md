---
title: Exploring the Docs
tags:
  - tutorials
  - getting-started
---

# Exploring the Documentation

> **Audiences:** All (Owner, AI, Reader, Contributor, Replicator)

This guide explains how the BlumeOps documentation is organized and how to find what you need.

## Documentation Structure

The docs follow the [Diataxis](https://diataxis.fr/) framework:

| Section | Purpose | When to Use |
|---------|---------|-------------|
| **[[tutorials|Tutorials]]** | Learning-oriented | "I'm new and want to understand" |
| **[[reference|Reference]]** | Information-oriented | "I need specific technical details" |
| **[[how-to|How-to]]** | Task-oriented | "I need to do X" |
| **[[explanation|Explanation]]** | Understanding-oriented | "I want to understand why" |

## Quick Paths by Audience

### For Erich (Owner)

You probably want quick access to operational details:
- [[how-to]] guides for common operations (deploy, troubleshoot, update ACLs)
- [[reference]] has service URLs, commands, and config locations
- [[ai-assistance-guide]] explains how to work effectively with Claude
- Run `mise run zk-docs` to prime AI context with key documentation

### For Claude/AI Agents

Context for effective assistance:
- Read [[ai-assistance-guide]] for operational conventions
- [[reference]] has the technical specifics you'll need
- The repo's `CLAUDE.md` has critical rules (especially the kubectl context requirement)

### For External Readers

Understanding what this is:
- [[explanation]] covers the "why" behind design decisions
- [[reference]] shows what's actually running
- Browse service pages to see specific implementations

### For Contributors

Getting started with changes:
- [[contributing]] walks through the workflow
- [[how-to]] guides for specific tasks (deploy services, add roles)
- [[reference]] tells you where things live

### For Replicators

Replicators are people who want to build their own similar homelab GitOps setup, using BlumeOps as inspiration.

- [[replicating-blumeops]] provides the overview, with linked tutorials that go deep on individual components
- [[explanation]] covers architecture and design rationale
- Reference pages show specific configuration choices

## Using Wiki Links

Documentation uses `[[wiki-links]]` for cross-references:
- `[[service-name]]` links to a reference page
- `[[page|Display Text]]` customizes the link text

When reading on the web (docs.eblu.me), these render as clickable links. The backlinks panel shows what references each page.

Pre-commit hooks automatically validate that all wiki-links point to existing files and that link targets are unambiguous.

## AI Context Priming

The `zk-docs` mise task concatenates key documentation files for AI context:

```bash
mise run zk-docs -- --style=header --color=never --decorations=always
```

This outputs the AI assistance guide, reference index, how-to index, architecture overview, and tutorials index - providing Claude with essential context for BlumeOps operations.

## Related

- [[tutorials]] - Parent index of all tutorials
- [[update-documentation]] - How to publish doc changes
- [[review-documentation]] - Periodic doc review process
