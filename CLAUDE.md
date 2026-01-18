# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure management, orchestrated via tailnet `tail8d86e.ts.net`.

**Critical: This repository is published publicly at https://github.com/eblume/blumeops, so never include any secrets!**

## Rules

1. At the start of every session, even if the user asked to do something else, run `mise run zk-docs -- --style=header --color=never --decorations=always` in order to review the `blumeops` documentation in the zettelkasten (zk). zk lives at `~/code/personal/zk`, and is managed via obsidian-sync (not git).

2. When making any changes, start by making sure you're on the `main` git branch and up-to-date, and then create a feature branch. Commit often while working, and create a PR using:
```fish
tea pr create --title "Description of change" --description "$(cat <<'EOF'
## Summary
- First change
- Second change

## Deployment and Testing
- [x] Done thing one
- [ ] Needed thing two

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
The user will review your work as you go, and will merge the pr as the last step in the process, even after deploying.

3. Always keep the zk cards up to date with any changes, and suggest new links to new cards whenever appropriate. Refer back to the zk docs often during the process of planning and making corrections to ensure accuracy, and if you make a mistake, figure out a way to guard against it using the zk.

4. Use `Brewfile` and `mise.toml` to install tools needed on the development workstation (typically hostnamed "gilbert", username "eblume").

5. Services are typically hosted on hostname "indri" and are launched from LaunchAgents of the user `erichblume`. If a service is available from `brew services` that is typically used, otherwise there is a utility called `mcquack` (`mcquack --help`) hosted at `https://forge.tail8d86e.ts.net/eblume/mcquack` - but you can just edit the mcquack launchagents directly via ansible.

6. Try to always test changes before applying them. Use syntax checkers, do dry runs (`--check --diff`), run commands manually via `ssh indri 'some command'`, etc.

7. **Wait for user review before deploying.** After creating a PR, do not run `mise run provision-indri` or other deployment commands until the user has had a chance to review the changes. The user will indicate when they're ready to deploy.

8. After deploying changes, try to verify the result. Use `mise run indri-services-check` to do a general service health check.

## Project structure
Some important places you can look:
```
./mise-tasks/  # management and utility scripts run via `mise run`
./ansible/playbooks/indri.yml  # primary blumeops provisioning script
./ansible/roles/  # role dirs here give good overview of services
./pulumi/  # python (via uv) pulumi script for provisioning the tailnet and other cloud resources
~/code/personal/  # projects managed by the user
~/code/3rd/  # external projects, mirrored or downloaded
~/code/work  # FORBIDDEN, never go here, avoid searching it
```

## Third-Party Projects

When a task requires cloning or using a third-party git repository (e.g., for building from source), **ask the user to mirror it on forge first**, then clone from the mirror:
- Mirror location: `https://forge.tail8d86e.ts.net/eblume/<project>.git`
- Clone to: `~/code/3rd/<project>/`

This avoids external dependencies and ensures the project is available even if the upstream is unreachable. Example mirrors:
- `https://forge.tail8d86e.ts.net/eblume/zot.git` (container registry)
- `https://forge.tail8d86e.ts.net/eblume/devpi.git` (PyPI proxy)

## Task Discovery

To discover pending blumeops tasks, run:

```fish
mise run blumeops-tasks
```

This fetches tasks from the "Blumeops" project in Todoist (via 1Password for API credentials) and displays them sorted by priority: p1 (urgent), p2 (high), p4 (normal/default), p3 (backlog). The typical workflow is to pick a task from this list at the start of a session, then dive in with planning.

## Credentials

The root store for credentials is 1password, which can be accessed via `op --vault <vaultid> item get <itemid> --field fieldname --reveal`, which will prompt the user for their assent and biometrics or password. Typically, use scripts to defer this action - try not to ever grab credentials directly. For instance, the indri.yml playbook starts with `pre_tasks` to gather the relevant secrets needed to provision its services. Some services have their credentials exported to files `chmod 0600` on indri, but they still start out in 1password. In some cases you can test services with a command that grabs the credential, but try to use environment variables or other arrangements to avoid learning the credential yourself, and warn the user first.
