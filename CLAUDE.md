# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure management, orchestrated via tailnet `tail8d86e.ts.net`.

## Documentation

Project documentation lives in the zettelkasten at `~/code/personal/zk`. Start with the project card: [1767747119-YCPO.md](~/code/personal/zk/1767747119-YCPO.md).

You are encouraged to explore the zk, follow links, and propose updates to it as the project evolves.

## Rules for all sessions

1. Always start by consulting the project card.
2. Expand and correct the cards of the zettelkasten.
3. Use `Brewfile` and `mise.toml` to install tools.
4. Use `brew services` or Launch Agents to control services on macos hosts.
5. Test all changes before applying them - ie with ansible, use a --check --diff run.

## Remote Hosts

This repo is typically edited from a workstation (e.g., gilbert), but services run on remote hosts in the tailnet. Use SSH to explore or check state on remote machines:

```bash
# Explore config paths on indri
ssh indri 'ls -la /opt/homebrew/etc/grafana/'

# Check service status
ssh indri 'brew services list'
```

Key hosts:
- **indri** - Mac Mini M1 running services (prometheus, grafana, kiwix, forgejo, borgmatic)
- **sifaka** - Synology NAS (backup target)

## Git Workflow

Use feature branches for all changes. Do not commit directly to main. Commit often while working to preserve progress.

```bash
# Create a feature branch
git checkout -b feature/description-of-change

# Make changes, then commit
git add -A
git commit -m "Description of change"

# Push and create PR using tea CLI
git push -u origin feature/description-of-change
tea pr create --title "Description of change" --description "Details..."
```

PRs are reviewed and merged via the Forgejo web UI at https://forge.tail8d86e.ts.net.

After creating a PR, run `open <pr-url>` to open it in the browser (Claude Code's UI will prompt for permission).

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
