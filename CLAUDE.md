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
