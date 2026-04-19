---
title: Exploring the Docs
modified: 2026-02-10
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
| **[Tutorials](/tutorials/)** | Learning-oriented | "I'm new and want to understand" |
| **[Reference](/reference/)** | Information-oriented | "I need specific technical details" |
| **[How-to](/how-to/)** | Task-oriented | "I need to do X" |
| **[Explanation](/explanation/)** | Understanding-oriented | "I want to understand why" |

## Quick Paths by Audience

### For Erich (Owner)

You probably want quick access to operational details:
- [How-to](/how-to/) guides for common operations (deploy, troubleshoot, update ACLs)
- [Reference](/reference/) has service URLs, commands, and config locations
- [[ai-assistance-guide]] explains how to work effectively with AI agents
- Run `mise run ai-docs` to prime AI context with key documentation

### For AI Agents

Context for effective assistance:
- Read [[ai-assistance-guide]] for operational conventions
- [Reference](/reference/) has the technical specifics you'll need
- The repo's `AGENTS.md` has critical rules (especially the kubectl context requirement)

### For External Readers

Understanding what this is:
- [Explanation](/explanation/) covers the "why" behind design decisions
- [Reference](/reference/) shows what's actually running
- Browse service pages to see specific implementations

### For Contributors

Getting started with changes:
- [[contributing]] walks through the workflow
- [How-to](/how-to/) guides for specific tasks (deploy services, add roles)
- [Reference](/reference/) tells you where things live

### For Replicators

Replicators are people who want to build their own similar homelab GitOps setup, using BlumeOps as inspiration.

- [[replicating-blumeops]] provides the overview, with linked tutorials that go deep on individual components
- [Explanation](/explanation/) covers architecture and design rationale
- Reference pages show specific configuration choices

## Using Wiki Links

Documentation uses `[[wiki-links]]` for cross-references:
- `[[service-name]]` links by filename stem (must be unambiguous)
- `[[path/to/file]]` links by path from docs root (for disambiguation)
- `[[page|Display Text]]` customizes the link text

When reading on the web (docs.eblu.me), these render as clickable links. The backlinks panel shows what references each page.

Prek hooks validate that all wiki-links resolve to existing files and flag ambiguous bare-name links.

## AI Context Priming

The `ai-docs` mise task concatenates key documentation files for AI context:

```bash
mise run ai-docs
```

This outputs key documentation files and a full tree listing of all docs, providing an agent with essential context for BlumeOps operations.

## Related

- [[update-documentation]] - How to publish doc changes
- [[review-documentation]] - Periodic doc review process
