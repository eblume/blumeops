---
title: add-ansible-role
tags:
  - how-to
  - ansible
---

# Add an Ansible Role

Quick reference for adding a new Ansible role to provision services on [[indri]].

## Create Role Structure

```
ansible/roles/<role>/
├── defaults/main.yml    # Default variables
├── tasks/main.yml       # Task definitions
├── handlers/main.yml    # Handlers (restarts, etc.)
├── templates/           # Jinja2 templates
└── files/               # Static files (optional)
```

## Minimal Role Example

```yaml
# ansible/roles/<role>/defaults/main.yml
---
role_data_dir: ~/Library/Application Support/<service>
role_port: 8080
```

```yaml
# ansible/roles/<role>/tasks/main.yml
---
- name: Ensure data directory exists
  ansible.builtin.file:
    path: "{{ role_data_dir }}"
    state: directory
    mode: '0755'

- name: Deploy configuration
  ansible.builtin.template:
    src: config.j2
    dest: "{{ role_data_dir }}/config"
    mode: '0644'
  notify: Restart service

- name: Deploy LaunchAgent plist
  ansible.builtin.template:
    src: launchagent.plist.j2
    dest: ~/Library/LaunchAgents/mcquack.<service>.plist
    mode: '0644'
  notify: Restart service
```

```yaml
# ansible/roles/<role>/handlers/main.yml
---
- name: Restart service
  ansible.builtin.shell: |
    launchctl unload ~/Library/LaunchAgents/mcquack.<service>.plist 2>/dev/null || true
    launchctl load ~/Library/LaunchAgents/mcquack.<service>.plist
  listen: Restart service
```

## Add Role to Playbook

Edit `ansible/playbooks/indri.yml`:

```yaml
  roles:
    # ... existing roles ...
    - role: <role>
      tags: [<role>]
```

## Add Secrets (if needed)

If the role needs secrets from 1Password, add pre_tasks:

```yaml
  pre_tasks:
    # ... existing pre_tasks ...
    - name: Fetch <role> secret
      ansible.builtin.command:
        cmd: op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get <item-id> --fields <field> --reveal
      delegate_to: localhost
      register: _role_secret
      changed_when: false
      no_log: true
      check_mode: false
      tags: [<role>]

    - name: Set <role> secret fact
      ansible.builtin.set_fact:
        role_secret_var: "{{ _role_secret.stdout }}"
      no_log: true
      tags: [<role>]
```

Then use `role_secret_var` in your role with a guard:

```yaml
# In role's tasks, fetch if not already set (allows running with --tags)
- name: Fetch secret if not set
  ansible.builtin.command:
    cmd: op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get <item-id> --fields <field> --reveal
  delegate_to: localhost
  register: _role_secret
  changed_when: false
  no_log: true
  check_mode: false
  when: role_secret_var is not defined
```

## Test and Deploy

```bash
# Dry run
mise run provision-indri -- --tags <role> --check --diff

# Apply
mise run provision-indri -- --tags <role>

# Verify
ssh indri 'launchctl list | grep <service>'
```

## Add Observability (optional)

For metrics collection, create a companion `<role>_metrics` role that:
1. Writes metrics to `/opt/homebrew/var/node_exporter/textfile/`
2. Runs via a LaunchAgent (cronjob-style)

See [[alloy]] for how metrics are collected from textfiles.

## Related

- [[reference/ansible/roles|Roles]] - Available roles reference
- [[indri]] - Target host
- [[observability]] - Metrics collection
