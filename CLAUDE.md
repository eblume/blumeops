# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure management, orchestrated via tailnet `tail8d86e.ts.net`.

**Critical: This repository is published publicly at https://github.com/eblume/blumeops, so never include any secrets!**

## Documentation

Project documentation lives in the zettelkasten at `~/code/personal/zk`. Read all blumeops documentation with:

```bash
mise run zk-docs -- --style=header --color=never --decorations=always
```

This displays all cards tagged `blumeops`, with the main project card first and filenames shown for each card.

You are encouraged to explore the zk, follow links, and propose updates to it as the project evolves. **Always keep the zettelkasten documentation up to date with any changes you make.**

## Rules for all sessions

1. Always start by reading the zk docs with the command above.
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

**IMPORTANT:** Always create feature branches from main to avoid including unrelated commits:

```bash
# Always start from main
git checkout main
git pull

# Create a feature branch
git checkout -b feature/description-of-change

# Make changes, then commit
git add -A
git commit -m "Description of change"

# Push and create PR using tea CLI
git push -u origin feature/description-of-change
tea pr create --title "Description of change" --description "$(cat <<'EOF'
## Summary
- First change
- Second change

## Test plan
- [x] Tested thing one
- [ ] Need to test thing two

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Note: `tea` uses `--description` (not `--body` like `gh`). Other useful flags:
- `--base <branch>` - target branch (default: repo's default branch)
- `--assignees <user>` - assign reviewers
- `--labels <label>` - add labels

PRs are reviewed and merged via the Forgejo web UI at https://forge.tail8d86e.ts.net.

After creating a PR, run `open <pr-url>` to open it in the browser (Claude Code's UI will prompt for permission).

## Ansible

```bash
# Install collection dependencies
ansible-galaxy collection install -r ansible/requirements.yml

# Dry-run before committing changes
mise run provision-indri -- --check --diff

# Apply changes
mise run provision-indri
```

## Service Health Checks

After making changes to services, run the service health check to verify everything is working:

```bash
mise run indri-services-check
```

This checks that all indri services (prometheus, grafana, kiwix, transmission, forgejo) are running and responding to health checks.
