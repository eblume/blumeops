---
title: exploring-the-docs
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
| **[[tutorials/index | Tutorials]]** | Learning-oriented | "I'm new and want to understand" |
| **[[reference/index | Reference]]** | Information-oriented | "I need specific technical details" |
| **[[how-to/index | How-to]]** | Task-oriented | "I need to do X" |
| **[[explanation/index | Explanation]]** | Understanding-oriented | "I want to understand why" |

## Quick Paths by Audience

### For Erich (Owner)

You probably want quick access to operational details:
- [[how-to/index|How-to guides]] for common operations (deploy, troubleshoot, update ACLs)
- [[reference/index|Reference]] has service URLs, commands, and config locations
- The `zk-docs` mise task still works for legacy zettelkasten access
- [[ai-assistance-guide]] explains how to work effectively with Claude

### For Claude/AI Agents

Context for effective assistance:
- Read [[ai-assistance-guide]] for operational conventions
- [[reference/index|Reference]] has the technical specifics you'll need
- The repo's `CLAUDE.md` has critical rules (especially the kubectl context requirement)

### For External Readers

Understanding what this is:
- [[explanation/index|Explanation]] covers the "why" behind design decisions
- [[reference/index|Reference]] shows what's actually running
- Browse service pages to see specific implementations

### For Contributors

Getting started with changes:
- [[contributing]] walks through the workflow
- [[how-to/index|How-to guides]] for specific tasks (deploy services, add roles)
- [[reference/index|Reference]] tells you where things live

### For Replicators

Replicators are people who want to build their own similar homelab GitOps setup, using BlumeOps as inspiration.

- [[replicating-blumeops]] provides the overview
- [[explanation/index|Explanation]] covers architecture and design rationale
- The `replication/` tutorials go deep on components
- Reference pages show specific configuration choices

## Using Wiki Links

Documentation uses `[[wiki-links]]` for cross-references:
- `[[service-name]]` links to a reference page
- `[[folder/page]]` links to nested pages
- `[[page | Display Text]]` customizes the link text

When reading on the web (docs.ops.eblu.me), these render as clickable links. The backlinks panel shows what references each page.

Pre-commit hooks automatically validate that all wiki-links point to existing files and that link targets are unambiguous.

## Legacy Content

The `docs/zk/` directory contains zettelkasten cards from before the restructuring. These are read-only reference - new content goes in the structured sections. The cards will eventually be migrated or archived.

To view legacy cards:
```bash
mise run zk-docs
```
