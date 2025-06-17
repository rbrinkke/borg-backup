# 🗄️ Borg Backup Solution

Automated backup system using BorgBackup with smart disaster recovery for Hetzner Linux servers.

## What it does

- 💾 Backs up your entire server to remote storage
- 🔒 Encrypts everything with AES-256
- 📅 Keeps daily backups for 30 days
- 🛡️ Protects target machine during restore

## Quick start

```bash
cd /opt/borg-backup/install
sudo ./install.sh
```

That's it. The script handles everything.

## What gets backed up

- `/home` - All user data
- `/etc` - System configuration  
- `/root` - Root user files
- `/var` - Databases, logs, application data
- `/opt` - Custom software installations
- `/usr/local` - Local binaries and configs

## What stays safe during restore

Your target machine keeps its:
- SSH configuration
- Firewall rules
- Network settings
- Hostname and hosts file

No lockouts. No broken connections.

## Files

- `install/install.sh` - Main installer
- `scripts/backup.sh` - Backup script template
- `README.md` - This file

## How it works

1. Install script checks prerequisites
2. Creates encrypted repository on remote storage
3. Copies backup script to `/usr/local/bin/borg-backup.sh`
4. Sets up daily automated backups at 3:00 AM
5. Tests everything works

## Manual backup

```bash
sudo /usr/local/bin/borg-backup.sh
```

## View backups

```bash
export BORG_PASSPHRASE=$(cat /etc/borg_passphrase.txt)
export BORG_RSH="sshpass -p PASSWORD ssh -4 -o StrictHostKeyChecking=no -p 23"
borg list ssh://USERNAME@HOST:23/./backup/main_repo
```

## Restore files

```bash
# List archive contents
borg list ssh://USERNAME@HOST:23/./backup/main_repo::ARCHIVE_NAME

# Extract to /tmp/restore
borg extract ssh://USERNAME@HOST:23/./backup/main_repo::ARCHIVE_NAME --target /tmp/restore
```

## Requirements

- Hetzner Linux server (Ubuntu/Debian or CentOS/RHEL)
- SSH access to Hetzner Storage Box (port 23)
- Root privileges

**Important**: Hetzner Storage Box uses SSH on port 23, not the standard port 22. The scripts use IPv4 (`-4` flag) because IPv6 connections may fail on some configurations.

## Security

- Repository encrypted with repokey method
- Passphrase stored in `/etc/borg_passphrase.txt` (600 permissions)
- SSH connections use password authentication
- All data encrypted before transmission

## Configuration

Edit these variables in `install/install.sh`:

```bash
STORAGE_BOX_USER="u12345"
STORAGE_BOX_HOST="u12345.your-storagebox.de"  
STORAGE_BOX_PORT="23"
```

## Support

This is a straightforward backup solution. If something breaks, check the logs:

```bash
tail -f /var/log/borg_backup.log
```

Most issues are SSH connectivity or storage space problems.

## Credits

❤️ Created by Rob ❤️ Claude Code ❤️

This procedure is specifically designed for backing up and restoring Hetzner Linux servers. A practical Dutch approach to backup solutions - no nonsense, just working code.

Special thanks to the community for IPv6/port configuration insights!

## License

Use it. Fix it. Share it. ☕
