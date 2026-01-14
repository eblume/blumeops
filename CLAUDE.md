# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure management, orchestrated via tailnet `tail8d86e.ts.net`.

## Documentation

Project documentation lives in the zettelkasten at `~/code/personal/zk`. Start with the project card: [1767747119-YCPO.md](~/code/personal/zk/1767747119-YCPO.md).

You are encouraged to explore the zk, follow links, and propose updates to it as the project evolves.

## Tool Preferences

1. **mise** - preferred for tool/runtime management (check first)
2. **homebrew** - for system packages

### Dependency Tracking

Track project dependencies in version control:
- **Brewfile** (repo root) - homebrew packages (`brew bundle`)
- **mise.toml** (per-directory) - runtimes and tools (`mise install`)

### Service Management

- **Homebrew services**: `brew services start|stop|restart <service>`
- **Non-homebrew services**: use `mcquack` (LaunchAgent manager for macOS)

## Ansible

Run playbooks from the `ansible/` directory.

```bash
# Install collection dependencies
ansible-galaxy collection install -r requirements.yml

# Dry-run before committing changes
ansible-playbook playbooks/indri.yml --check --diff

# Apply changes
ansible-playbook playbooks/indri.yml
```

**Always dry-run (`--check --diff`) ansible changes before committing.**
