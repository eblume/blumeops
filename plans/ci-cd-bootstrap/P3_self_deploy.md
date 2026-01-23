# Phase 3: Self-Deploy & Transition to mcquack

**Goal**: Complete the bootstrap - Forgejo deploys itself, transition from brew to mcquack LaunchAgent

**Status**: Planning

**Prerequisites**: [Phase 2](P2_mirror_and_build.md) complete (build workflow produces valid binaries)

---

## Overview

This phase completes the bootstrap:
1. First successful CI deploy creates the binary
2. Transition from brew service to mcquack LaunchAgent
3. Update ansible role to mcquack pattern
4. Remove brew forgejo

After this phase, Forgejo builds and deploys itself on every tagged release.

---

## Step 1: Prepare indri for mcquack

### 1.1 Create Directory Structure

```bash
ssh indri << 'EOF'
  mkdir -p ~/.local/bin
  mkdir -p ~/.config/forgejo
  mkdir -p ~/Library/Logs
EOF
```

### 1.2 Prepare Data Directory

The existing data is at `/opt/homebrew/var/forgejo`. We'll keep it there for now (simpler), or optionally migrate to `~/forgejo`.

**Option A: Keep existing path** (recommended for simplicity)
- Data stays at `/opt/homebrew/var/forgejo`
- Binary moves to `~/.local/bin/forgejo`

**Option B: Full migration**
- Move data to `~/forgejo`
- Requires updating app.ini paths

For this plan, we'll use Option A.

---

## Step 2: First CI Deploy

### 2.1 Trigger Build with Deploy

1. Go to https://forge.tail8d86e.ts.net/eblume/forgejo/actions
2. Select "Build Forgejo" workflow
3. Click "Run workflow"
4. Set deploy=true
5. Monitor the run

### 2.2 Verify Binary Deployed

```bash
ssh indri 'ls -la ~/.local/bin/forgejo && ~/.local/bin/forgejo --version'
```

At this point:
- New binary is at `~/.local/bin/forgejo`
- Brew forgejo is still running
- LaunchAgent doesn't exist yet

---

## Step 3: Create mcquack LaunchAgent

### 3.1 Create Plist Manually (One-Time Bootstrap)

```bash
ssh indri << 'EOF'
cat > ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>mcquack.eblume.forgejo</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/erichblume/.local/bin/forgejo</string>
    <string>web</string>
    <string>--config</string>
    <string>/opt/homebrew/var/forgejo/custom/conf/app.ini</string>
    <string>--work-path</string>
    <string>/opt/homebrew/var/forgejo</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/Users/erichblume/Library/Logs/mcquack.forgejo.out.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/erichblume/Library/Logs/mcquack.forgejo.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>/Users/erichblume</string>
    <key>USER</key>
    <string>erichblume</string>
  </dict>
</dict>
</plist>
PLIST
EOF
```

---

## Step 4: Cutover from Brew to mcquack

### 4.1 Stop Brew Service

```bash
ssh indri 'brew services stop forgejo'
```

### 4.2 Start mcquack Service

```bash
ssh indri 'launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist'
```

### 4.3 Verify Service Running

```bash
# Check process
ssh indri 'launchctl list | grep forgejo'

# Check logs
ssh indri 'tail -20 ~/Library/Logs/mcquack.forgejo.err.log'

# Check HTTP
curl -s https://forge.tail8d86e.ts.net/api/v1/version
```

### 4.4 Verify Git Operations

```bash
# SSH test
ssh -T forgejo@forge.tail8d86e.ts.net

# Clone test
git clone ssh://forgejo@forge.tail8d86e.ts.net/eblume/blumeops.git /tmp/test-clone
rm -rf /tmp/test-clone
```

---

## Step 5: Update Ansible Role

### 5.1 Rewrite forgejo Role

Replace `ansible/roles/forgejo/tasks/main.yml`:

```yaml
---
# Forgejo is built from source via CI and deployed automatically.
# This role manages the configuration and LaunchAgent only.
#
# BINARY DEPLOYMENT:
# The binary at ~/.local/bin/forgejo is deployed by Forgejo Actions CI.
# If missing, trigger a build at:
#   https://forge.tail8d86e.ts.net/eblume/forgejo/actions
#
# CONFIGURATION:
# app.ini at /opt/homebrew/var/forgejo/custom/conf/app.ini contains secrets
# and is NOT managed by ansible. It is backed up by borgmatic.

- name: Verify forgejo binary exists
  ansible.builtin.stat:
    path: "{{ forgejo_binary }}"
  register: forgejo_binary_stat

- name: Fail if forgejo binary not found
  ansible.builtin.fail:
    msg: |
      Forgejo binary not found at {{ forgejo_binary }}.

      The binary is deployed by Forgejo Actions CI. To build and deploy:
      1. Go to https://forge.tail8d86e.ts.net/eblume/forgejo/actions
      2. Select "Build Forgejo" workflow
      3. Click "Run workflow" with deploy=true

      Alternatively, build manually on gilbert and scp to indri.
  when: not forgejo_binary_stat.stat.exists

- name: Check forgejo config exists
  ansible.builtin.stat:
    path: "{{ forgejo_config }}"
  register: forgejo_config_stat

- name: Fail if forgejo config is missing
  ansible.builtin.fail:
    msg: |
      Forgejo config not found at {{ forgejo_config }}
      This file contains secrets and is not managed by ansible.
      To restore from backup, run:
        borgmatic --config ~/.config/borgmatic/config.yaml extract --archive latest \
        --path {{ forgejo_config }}
  when: not forgejo_config_stat.stat.exists

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

### 5.2 Create defaults/main.yml

```yaml
---
# Forgejo binary and paths
forgejo_binary: /Users/erichblume/.local/bin/forgejo
forgejo_work_path: /opt/homebrew/var/forgejo
forgejo_config: "{{ forgejo_work_path }}/custom/conf/app.ini"
forgejo_log_dir: /Users/erichblume/Library/Logs

# HTTP and SSH ports (must match app.ini)
forgejo_http_port: 3001
forgejo_ssh_port: 2200
```

### 5.3 Create templates/forgejo.plist.j2

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
    <string>web</string>
    <string>--config</string>
    <string>{{ forgejo_config }}</string>
    <string>--work-path</string>
    <string>{{ forgejo_work_path }}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>{{ forgejo_log_dir }}/mcquack.forgejo.out.log</string>
  <key>StandardErrorPath</key>
  <string>{{ forgejo_log_dir }}/mcquack.forgejo.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>/Users/erichblume</string>
    <key>USER</key>
    <string>erichblume</string>
  </dict>
</dict>
</plist>
```

### 5.4 Update handlers/main.yml

```yaml
---
- name: Restart forgejo
  ansible.builtin.shell: |
    launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist
  changed_when: true
```

---

## Step 6: Update Alloy Log Collection

Update `ansible/roles/alloy/defaults/main.yml`:

Change forgejo log paths from brew to mcquack:
```yaml
alloy_brew_logs:
  # Remove forgejo from here
  - path: /opt/homebrew/var/log/tailscaled.log
    service: tailscale
    stream: stdout

alloy_mcquack_logs:
  # ... existing entries ...
  - path: /Users/erichblume/Library/Logs/mcquack.forgejo.out.log
    service: forgejo
    stream: stdout
  - path: /Users/erichblume/Library/Logs/mcquack.forgejo.err.log
    service: forgejo
    stream: stderr
```

---

## Step 7: Remove Brew Forgejo

### 7.1 Uninstall Brew Package

```bash
ssh indri 'brew uninstall forgejo'
```

### 7.2 Remove Old Logs

```bash
ssh indri 'rm -f /opt/homebrew/var/log/forgejo.log'
```

---

## Step 8: Run Ansible

```bash
mise run provision-indri -- --tags forgejo,alloy
```

---

## Disaster Recovery

### If CI Deploy Breaks Forgejo

1. **Build manually on gilbert**:
   ```bash
   cd ~/code/3rd/forgejo
   git pull
   mise use go node
   TAGS="bindata sqlite sqlite_unlock_notify" make build
   scp gitea indri:~/.local/bin/forgejo
   ```

2. **Restart service**:
   ```bash
   ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist; launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist'
   ```

3. **Verify**:
   ```bash
   curl https://forge.tail8d86e.ts.net/api/v1/version
   ```

### If Forgejo Won't Start

1. Check logs: `ssh indri 'tail -100 ~/Library/Logs/mcquack.forgejo.err.log'`
2. Check binary: `ssh indri '~/.local/bin/forgejo --version'`
3. Check config: `ssh indri 'cat /opt/homebrew/var/forgejo/custom/conf/app.ini | head -50'`
4. Try running manually: `ssh indri '~/.local/bin/forgejo web --config /opt/homebrew/var/forgejo/custom/conf/app.ini --work-path /opt/homebrew/var/forgejo'`

### Switch ArgoCD to GitHub (Nuclear Option)

If Forgejo is down and you need to deploy fixes:

```bash
argocd repo add https://github.com/eblume/blumeops.git --username eblume --password $GITHUB_PAT
argocd app set apps --repo https://github.com/eblume/blumeops.git
argocd app sync apps
```

After recovery, switch back to Forgejo.

---

## Verification Checklist

- [ ] CI deploy completed successfully
- [ ] Binary at `~/.local/bin/forgejo`
- [ ] mcquack LaunchAgent created
- [ ] Brew service stopped
- [ ] mcquack service started
- [ ] HTTP works (`curl https://forge.tail8d86e.ts.net/api/v1/version`)
- [ ] SSH works (`ssh -T forgejo@forge.tail8d86e.ts.net`)
- [ ] Git clone/push works
- [ ] Ansible role updated
- [ ] Alloy logs updated
- [ ] Brew package uninstalled
- [ ] `mise run provision-indri` succeeds

---

## Next Phase

After bootstrap is complete, proceed to [Phase 4: Container Builds](P4_container_builds.md) to set up container image building for ArgoCD.
