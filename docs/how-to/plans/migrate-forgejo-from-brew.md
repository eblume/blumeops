---
title: "Plan: Migrate Forgejo from Brew to Source Build"
date-modified: 2026-02-10
tags:
  - how-to
  - plans
  - forgejo
---

# Plan: Migrate Forgejo from Brew to Source Build

> **Status:** Planned (not yet executed)

## Background

Forgejo was force-upgraded from v13 to v14 by `brew upgrade`, breaking version control. To prevent uncontrolled upgrades and align with the established pattern for other native services (zot, caddy, alloy), we are transitioning Forgejo from Homebrew to a source-built binary managed by a LaunchAgent.

### Why Source Build?

- **Version pinning** — upgrade on our schedule by checking out specific tags
- **Consistency** — matches [[zot]], [[caddy]], and [[alloy]] deployment patterns
- **Control** — build flags, patches, and dependencies are explicit

## Source Remote

Use **Codeberg upstream** as the primary clone source to avoid a circular dependency (Forgejo hosting its own source):

```
https://codeberg.org/forgejo/forgejo.git
```

Add the forge mirror as a secondary remote for convenience and backup:

```
https://forge.ops.eblu.me/eblume/forgejo.git
```

## One-Time Migration Steps

These steps are performed manually on indri **before** running Ansible.

### 1. Clone Forgejo from Codeberg

```fish
ssh indri 'git clone https://codeberg.org/forgejo/forgejo.git ~/code/3rd/forgejo'
```

### 2. Add Forge Mirror as Secondary Remote

```fish
ssh indri 'cd ~/code/3rd/forgejo && git remote add forge https://forge.ops.eblu.me/eblume/forgejo.git'
```

### 3. Check Out the Desired Version Tag

```fish
ssh indri 'cd ~/code/3rd/forgejo && git checkout v14.0.1'
```

### 4. Create a Local Deployment Branch

Create a local-only `indri-deployment` branch to track the deployed version. Rebase this branch when upgrading to new tags:

```fish
ssh indri 'cd ~/code/3rd/forgejo && git checkout -b indri-deployment'
```

### 5. Set Up Build Dependencies via Mise

Forgejo requires Go 1.24+ and Node 20+:

```fish
ssh indri 'cd ~/code/3rd/forgejo && mise use go@1.24 node@20'
```

### 6. Build the Binary

```fish
ssh indri 'cd ~/code/3rd/forgejo && TAGS="bindata timedzdata sqlite sqlite_unlock_notify" mise x -- make build'
```

This produces `./forgejo` in the repo root.

### 7. Stop Brew Forgejo

```fish
ssh indri 'brew services stop forgejo'
```

### 8. Copy Data to New Location

```fish
ssh indri 'sudo cp -a /opt/homebrew/var/forgejo ~/forgejo'
```

### 9. Fix Ownership

```fish
ssh indri 'sudo chown -R erichblume:staff ~/forgejo'
```

### 10. Run Ansible to Deploy New Config + LaunchAgent

```fish
mise run provision-indri -- --tags forgejo
```

### 11. Verify Service Health

See the verification checklist below.

### 12. Uninstall Brew Forgejo

Only after verifying everything works:

```fish
ssh indri 'brew uninstall forgejo'
```

## Ansible Role Changes

The following changes to `ansible/roles/forgejo/` should be made in the execution session.

### `defaults/main.yml`

Update paths and add new variables to match the zot pattern (`ansible/roles/zot/defaults/main.yml`):

```yaml
# Source build paths
forgejo_repo_dir: /Users/erichblume/code/3rd/forgejo
forgejo_binary: "{{ forgejo_repo_dir }}/forgejo"

# Data paths (migrated from brew)
forgejo_work_path: /Users/erichblume/forgejo
forgejo_config_path: "{{ forgejo_work_path }}/custom/conf/app.ini"
forgejo_data_path: "{{ forgejo_work_path }}/data"
forgejo_log_path: "{{ forgejo_work_path }}/log"
forgejo_log_dir: /Users/erichblume/Library/Logs

# RUN_USER changes from 'forgejo' to 'erichblume' (LaunchAgent user)
forgejo_run_user: erichblume
```

### `tasks/main.yml`

Replace brew install/start with binary-check + LaunchAgent pattern (matching `ansible/roles/zot/tasks/main.yml`):

```yaml
---
# Forgejo role — source-built binary with LaunchAgent
#
# ONE-TIME SETUP (before running ansible):
#
# 1. Clone forgejo from codeberg (avoid circular dependency):
#    ssh indri 'git clone https://codeberg.org/forgejo/forgejo.git ~/code/3rd/forgejo'
#
# 2. Add forge mirror as secondary remote:
#    ssh indri 'cd ~/code/3rd/forgejo && git remote add forge https://forge.ops.eblu.me/eblume/forgejo.git'
#
# 3. Set up Go and Node via mise:
#    ssh indri 'cd ~/code/3rd/forgejo && mise use go@1.24 node@20'
#
# 4. Build:
#    ssh indri 'cd ~/code/3rd/forgejo && TAGS="bindata timedzdata sqlite sqlite_unlock_notify" mise x -- make build'
#
# 5. Run ansible to deploy config and LaunchAgent

- name: Verify forgejo binary exists
  ansible.builtin.stat:
    path: "{{ forgejo_binary }}"
  register: forgejo_binary_stat

- name: Fail if forgejo binary not found
  ansible.builtin.fail:
    msg: |
      Forgejo binary not found at {{ forgejo_binary }}.
      Please build from source first:
        ssh indri 'cd ~/code/3rd/forgejo && TAGS="bindata timedzdata sqlite sqlite_unlock_notify" mise x -- make build'
  when: not forgejo_binary_stat.stat.exists

- name: Ensure forgejo config directory exists
  ansible.builtin.file:
    path: "{{ forgejo_work_path }}/custom/conf"
    state: directory
    mode: '0755'

- name: Deploy forgejo config
  ansible.builtin.template:
    src: app.ini.j2
    dest: "{{ forgejo_config_path }}"
    mode: '0600'
  notify: Restart forgejo

- name: Deploy forgejo LaunchAgent plist
  ansible.builtin.template:
    src: forgejo.plist.j2
    dest: ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist
    mode: '0644'
  notify: Restart forgejo

- name: Check if forgejo LaunchAgent is loaded
  ansible.builtin.command: launchctl list mcquack.eblume.forgejo
  register: forgejo_launchctl_check
  changed_when: false
  failed_when: false

- name: Load forgejo LaunchAgent if not loaded
  ansible.builtin.command: launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist
  when: forgejo_launchctl_check.rc != 0
  changed_when: true
  failed_when: false
```

### `handlers/main.yml`

Replace `brew services restart` with `launchctl unload/load` (matching `ansible/roles/zot/handlers/main.yml`):

```yaml
---
- name: Restart forgejo
  ansible.builtin.shell: |
    launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist
  changed_when: true
```

### New Template: `forgejo.plist.j2`

LaunchAgent plist (matching `ansible/roles/zot/templates/zot.plist.j2`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- {{ ansible_managed }} -->
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>mcquack.eblume.forgejo</string>
	<key>ProgramArguments</key>
	<array>
		<string>{{ forgejo_binary }}</string>
		<string>-w</string>
		<string>{{ forgejo_work_path }}</string>
		<string>-c</string>
		<string>{{ forgejo_config_path }}</string>
		<string>web</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>{{ forgejo_log_dir }}/mcquack.forgejo.out.log</string>
	<key>StandardErrorPath</key>
	<string>{{ forgejo_log_dir }}/mcquack.forgejo.err.log</string>
</dict>
</plist>
```

### `app.ini.j2`

No changes needed — paths already flow through variables in `defaults/main.yml`. The only change is that `RUN_USER` will pick up `erichblume` from the updated default.

## What Stays the Same

- **1Password secret fetching** — playbook `pre_tasks` are unchanged
- **`forgejo_actions_secrets` role** — API-based secret sync is unaffected
- **SSH clone URLs** — `BUILTIN_SSH_SERVER_USER` stays `forgejo` (this is the git SSH user, not the OS user)
- **Caddy routing** — still proxies to `localhost:3001`
- **SQLite database** — copied as-is to new location
- **All `app.ini` settings** — template is unchanged, just re-rendered with new paths

## Verification Checklist

After running the migration and Ansible:

- [ ] `ssh indri 'launchctl list mcquack.eblume.forgejo'` — shows running
- [ ] `curl https://forge.ops.eblu.me/api/v1/version` — returns JSON with version
- [ ] Git clone over SSH: `git clone ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git /tmp/test-clone`
- [ ] Git push works on an existing clone
- [ ] Ansible dry-run is clean: `mise run provision-indri -- --tags forgejo --check --diff`
- [ ] `mise run services-check` — all green
- [ ] Forgejo Actions runners reconnect and jobs succeed

## Future Considerations

- **CI-built binaries** — build on gilbert or in Forgejo Actions, deploy as artifact
- **Artifact release system** — tag-triggered binary builds, similar to container releases (`mise run container-release`)
- **Automated upgrades** — Renovate or similar watching Codeberg tags, opening PRs with version bumps
- **Indri user management** — run each service as its own macOS user for isolation (a `forgejo` user exists but LaunchAgent session management under non-login users is tricky on macOS)

## Reference Pattern Files

| File | Purpose |
|------|---------|
| `ansible/roles/zot/tasks/main.yml` | Primary pattern for source-built binary tasks |
| `ansible/roles/zot/defaults/main.yml` | Variable naming conventions |
| `ansible/roles/zot/templates/zot.plist.j2` | LaunchAgent plist template |
| `ansible/roles/zot/handlers/main.yml` | Handler pattern (launchctl unload/load) |
