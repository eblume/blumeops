---
title: Run 1Password Backup
modified: 2026-09-09
last-reviewed: 2026-09-09
tags:
  - how-to
  - operations
  - backup
---

# Run 1Password Backup

How to export and encrypt your 1Password vaults for inclusion in [[borgmatic]] backups. Run this periodically from your local machine (Gilbert).

## Prerequisites

- 1Password desktop app running (for the vault export)
- `op`, `age`, `openssl`, `ssh`, and `scp` installed locally
- SSH access to [[indri]]
- The `op` CLI signed in (biometric unlock)

## Procedure

### 1. Export Vaults From 1Password

1. Open the 1Password desktop app
2. **File > Export > Blume/Davis** (the menu item is named after the account, not "All Vaults" — exporting the account covers all vaults: Private, blumeops, Payrix, Shared, and agents. A newly-added vault is swept in automatically because the export is account-wide; no per-vault selection.)
3. Choose **1PUX** format
4. Save to `~/Documents/` — 1Password names the file `1PasswordExport-<account-uuid>-<timestamp>.1pux` automatically; don't bother renaming it, pass the path to the task in the next step

> [!warning] The export folder must be local, not iCloud-synced
> The `.1pux` is plaintext. Gilbert's `~/Documents` is a plain local folder
> today (Desktop & Documents iCloud sync is **off** on Gilbert), so the
> export never leaves the disk before the task encrypts and deletes it. If
> that setting is ever turned on, `~/Documents` becomes iCloud Drive and a
> plaintext export would upload within seconds and linger in iCloud's
> Recently Deleted for 30 days. Check before exporting:
>
> ```fish
> readlink ~/Library/Mobile\ Documents/com~apple~CloudDocs/Documents
> ```
>
> Empty output means the iCloud folder is a separate directory and
> `~/Documents` is local — safe. If it prints `/Users/eblume/Documents`, the
> two are the same folder: export somewhere else (e.g. `~/tmp/`) and pass
> that path to the task. Use `readlink`, not `stat`: `stat` without `-L`
> reports a symlink's own inode and will tell you the folders differ when
> they don't (verified the hard way, 2026-09-09).

### 2. Run the Backup Task

Pass the exported file's path:

```fish
mise run op-backup ~/Documents/1PasswordExport-*.1pux
```

(If only one export exists in `~/Documents/`, the glob expands cleanly. Otherwise, paste the full path.)

The task will:

1. Prompt for the `.1pux` path if not provided
2. Fetch your master password and secret key from 1Password (triggers biometric)
3. Generate a temporary age key pair
4. Encrypt the `.1pux` with the age public key
5. Encrypt the age private key with OpenSSL AES-256-CBC (passphrase: `{master_password}:{secret_key}`)
6. SCP both encrypted files to `indri:/Users/erichblume/Documents/1password-backup/`
7. Clean up old backups on indri (keeps last 3 sets)
8. **Delete the plaintext `.1pux` from Gilbert**

No cleanup needed — the script automatically deletes the plaintext `.1pux` from Gilbert and shreds the temporary encryption keys.

### 3. Verify

After the script completes, confirm the files landed on indri:

```fish
ssh indri 'ls -lh /Users/erichblume/Documents/1password-backup/'
```

You should see a `.age` file (~30-45 MB) and a `.key.enc` file (~200 bytes) with today's timestamp. The directory is mode `700` and the files `600` (the task sets both after the copy; indri's umask would otherwise leave them world-readable).

> [!danger] indri's `~/Documents` **is** iCloud Drive — never delete from the iCloud side
> On indri, Desktop & Documents sync is on by design, so
> `~/Library/Mobile Documents/com~apple~CloudDocs/Documents` is a symlink to
> `~/Documents`. The `1password-backup/` folder therefore also appears under
> iCloud Drive › Documents on every Mac signed into the account. That is the
> same folder, not a copy: deleting it from any Mac (Finder or `rm`) syncs
> the delete to indri and removes the sets that have not yet been archived by
> borgmatic. Leave the iCloud view alone; the task prunes to 3 sets on its
> own. This happened on 2026-09-09 (issue #958); recovery is in
> [[restore-1password-backup]] plus iCloud Recently Deleted for a same-day set.

## What Happens Next

Borgmatic picks up the encrypted files during its daily 2:00 AM backup run, archiving them to both [[sifaka]] (local NAS) and BorgBase (offsite). No further action needed.

## Related

- [[restore-1password-backup]] - Disaster recovery: how to decrypt and restore
- [[1password]] - 1Password service overview
- [[borgmatic]] - Backup system
- [[backups]] - Backup policy and schedule
