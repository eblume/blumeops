---
id: indri
aliases:
  - indri
  - mac-mini
tags:
  - blumeops
---

# Indri Maintenance Log

Indri is a Mac Mini M1 (2020) serving as the primary [[1767747119-YCPO|BlumeOps]] server.

## Host Details

- Model: Mac mini M1, 2020 (Macmini9,1)
- Storage: 2TB internal SSD
- macOS: 15.7.3 (Sequoia)
- Role: Primary server for homelab services

## Passwordless Sudo

Configured passwordless sudo for `erichblume` user to allow ansible `become: true` tasks to run without password prompts:

```bash
# Config at /etc/sudoers.d/erichblume
erichblume ALL=(ALL) NOPASSWD: ALL
```

This is acceptable given the security model - tailnet access is the trust boundary.

## Sleep Prevention

Indri must stay awake to serve network requests. Currently using **Amphetamine** (App Store) to prevent sleep.

**Configuration:**
- Start Session At Launch: enabled
- Default Duration: indefinite
- Allow Closed-Display Sleep: enabled (no display attached)

**Known Issue:** Amphetamine can crash after extended uptime (~12 days observed), leaving the system unprotected. If this becomes a recurring problem, consider switching to system-level sleep prevention:

```bash
# Option 1: Disable sleep via pmset (requires sudo)
sudo pmset -c sleep 0 displaysleep 0

# Option 2: Use caffeinate daemon via LaunchAgent
# Create ~/Library/LaunchAgents/com.local.caffeinate.plist
caffeinate -s  # -s = prevent sleep on AC power
```

These could be managed via ansible for reliability.

## Log

### Mon Jan 20 2026

**Amphetamine crash caused overnight sleep**

- Amphetamine 5.3.2 crashed at 19:08 on Jan 19 (segfault in `objc_release` during timer callback)
- System went to sleep at 19:20, stayed asleep overnight
- Discovered when services were unreachable; manually restarted Amphetamine at ~07:30
- Crash report: `~/Library/Logs/DiagnosticReports/Amphetamine-2026-01-19-190921.ips`
- Root cause: Memory management bug in Amphetamine during long-running session (~12 days uptime)
- Action: Monitoring for now; if recurs, will implement `pmset`/`caffeinate` via ansible
