---
title: Restore 1Password Backup
tags:
  - how-to
  - operations
  - backup
---

# Restore 1Password Backup

How to recover a 1Password `.1pux` export from a [[borgmatic]] backup. This procedure assumes the worst case — [[indri]] and [[sifaka]] may both be gone. All you need is a copy of the borg repository and your Emergency Kit.

## Prerequisites

- A copy of the borg backup repository (from [[sifaka]], or an off-site copy — TBD)
- `borg`, `age`, and `openssl` installed on any machine
- Your **1Password Emergency Kit** (fire safety box) — contains the master password and secret key
- The borg repo passphrase (printed on the Emergency Kit, or from `/Users/erichblume/.borg/config.yaml` if [[indri]] is accessible)

## When to Use This

Use this procedure when you've lost access to 1Password and need to recover credentials from the encrypted backup created by `mise run op-backup`.

## Procedure

### 1. Extract From Borg Repository

If you have direct access to the borg repository (e.g. mounted from [[sifaka]] or restored from off-site), extract directly:

```bash
mkdir -p /tmp/op-restore && cd /tmp/op-restore
BORG_PASSPHRASE="<your-borg-passphrase>" borg list /path/to/borg/repo --last 5
BORG_PASSPHRASE="<your-borg-passphrase>" borg extract \
  "/path/to/borg/repo::<archive-name>" \
  Users/erichblume/Documents/1password-backup/
```

If [[indri]] is available, you can use borgmatic instead:

```bash
ssh indri 'cd /tmp && mkdir -p op-restore && cd op-restore && \
  BORG_PASSCOMMAND="cat /Users/erichblume/.borg/config.yaml" \
  /opt/homebrew/bin/borg extract \
  "/Volumes/backups/borg/::<archive-name>" \
  Users/erichblume/Documents/1password-backup/'
```

Verify you have a `.age` file (~30-45 MB) and a `.key.enc` file (~200 bytes).

### 2. Decrypt the Age Private Key

The private key is encrypted with `openssl aes-256-cbc`. The passphrase is `{master_password}:{secret_key}` from your Emergency Kit.

```bash
cd /tmp/op-restore/Users/erichblume/Documents/1password-backup
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in 1password-export-*.key.enc \
  -out key.txt
```

Enter the passphrase when prompted: `{master_password}:{secret_key}` (colon-separated, no spaces around the colon).

### 3. Decrypt the Export

```bash
age -d -i key.txt < 1password-export-*.age > export.1pux
```

### 4. Verify

The `.1pux` file is a zip archive. Verify it looks correct:

```bash
file export.1pux        # Should say "Zip archive data"
ls -lh export.1pux      # Should be ~30-45 MB
unzip -l export.1pux | head -20  # Should list files/ entries
```

### 5. Import Into 1Password

Open 1Password and use **File > Import** to restore from the `.1pux` file.

### 6. Clean Up

Remove all temporary files — the decrypted export and key contain secrets:

```bash
rm -rf /tmp/op-restore
```

## Notes on the Borg Passphrase

The borg repo uses `repokey` encryption — the key is stored in the repo itself, so you only need the passphrase (not a separate keyfile). The passphrase is recorded on your Emergency Kit alongside the 1Password credentials.

## Related

- [[borgmatic]] - Backup system
- [[1password]] - Credential management
- [[backups]] - Backup policy and schedule
- [[disaster-recovery]] - Overall disaster recovery
