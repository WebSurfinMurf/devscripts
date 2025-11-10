# Multi-User Project Backup System

## Overview

Automated backup system for project data with multi-user support and automatic mounting on boot.

**Thumb Drive Details:**
- Device: `/dev/sda4`
- Model: SanDisk 3.2Gen1
- Size: 454.3GB
- Filesystem: ext4
- Mount Point: `/mnt/backup` (auto-mounts on boot)

**Multi-User Structure:**
```
/mnt/backup/backups/usr/
├── administrator/
│   └── projects/
│       ├── data/
│       ├── nginx/
│       └── [other projects]/
├── websurfinmurf/
│   └── projects/
├── apprunner/
│   └── projects/
└── joe/
    └── projects/
```

**Security:**
- Each user can only access their own backup directory
- Permissions: 700 (drwx------) - user-only access
- Each user owns their directory completely

## Initial Setup (Run Once)

### Step 1: Run Setup Script (Requires sudo)

```bash
sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh
```

This script will:
1. ✅ Create `/mnt/backup` mount point
2. ✅ Add `/dev/sda4` to `/etc/fstab` for auto-mount on boot
3. ✅ Mount the drive immediately
4. ✅ Create multi-user directory structure
5. ✅ Set proper permissions (each user owns their directory)

**fstab entry created:**
```
/dev/sda4  /mnt/backup  ext4  defaults,nofail  0  2
```

**What `nofail` means:** System will boot successfully even if USB drive is disconnected.

### Step 2: Verify Setup

```bash
# Check if mounted
mount | grep /mnt/backup

# Check your backup directory exists and you can write to it
ls -ld /mnt/backup/backups/usr/$(whoami)
touch /mnt/backup/backups/usr/$(whoami)/test.txt && rm /mnt/backup/backups/usr/$(whoami)/test.txt && echo "✓ Write access OK"
```

## Usage

### Backup Your Project Data

The backup script automatically detects the current user and backs up to their directory.

**Default (backs up 'data' project):**
```bash
/home/administrator/projects/devscripts/backup/backup-projects-data.sh
```

**Specific project:**
```bash
/home/administrator/projects/devscripts/backup/backup-projects-data.sh nginx
/home/administrator/projects/devscripts/backup/backup-projects-data.sh mcp
/home/administrator/projects/devscripts/backup/backup-projects-data.sh admin
```

**Dry run (test without changes):**
```bash
/home/administrator/projects/devscripts/backup/backup-projects-data.sh data --dry-run
```

### Examples

```bash
# Administrator backs up their data project
administrator$ /home/administrator/projects/devscripts/backup/backup-projects-data.sh data
# → Backs up to: /mnt/backup/backups/usr/administrator/projects/data/

# websurfinmurf backs up their data
websurfinmurf$ /home/websurfinmurf/projects/devscripts/backup/backup-projects-data.sh data
# → Backs up to: /mnt/backup/backups/usr/websurfinmurf/projects/data/

# Administrator backs up nginx project
administrator$ /home/administrator/projects/devscripts/backup/backup-projects-data.sh nginx
# → Backs up to: /mnt/backup/backups/usr/administrator/projects/nginx/
```

## Auto-Mount on Boot

The drive is configured to **auto-mount on every boot** via `/etc/fstab`.

**After server restart:**
```bash
# Check if auto-mounted
mount | grep /mnt/backup

# If not mounted (drive disconnected), reconnect drive and:
sudo mount -a
```

## Backup Script Features

- ✅ **Multi-user support**: Each user backs up to their own directory
- ✅ **User isolation**: Users cannot access other users' backups
- ✅ **Incremental backups**: Only copies changed files (rsync)
- ✅ **Project selection**: Backup specific projects by name
- ✅ **Delete synchronization**: Removes files from backup that were deleted from source
- ✅ **Progress display**: Shows real-time transfer progress
- ✅ **Statistics**: Detailed summary of transferred files
- ✅ **Logging**: All backups logged to `~/logs/backups/`
- ✅ **Safety checks**: Verifies mount point, permissions, and available space
- ✅ **Timestamp tracking**: Creates `.last-backup` file with user and project info

## What Gets Backed Up

Everything in `/home/{username}/projects/{projectname}/` except:
- `.tmp` files and directories
- `*.tmp` files
- `*.log` files
- `lost+found` directories

## Directory Structure Example

For **administrator** user backing up **data** project:

```
Source:      /home/administrator/projects/data/
Destination: /mnt/backup/backups/usr/administrator/projects/data/

/mnt/backup/backups/usr/administrator/projects/data/
├── .last-backup           # Timestamp and backup info
├── arangodb/
├── grafana/
├── keycloak-postgres/
├── litellm/
├── loki/
├── minio/
└── ... (all subdirectories)
```

## Logs

Backup logs are stored in: `~/projects/devscripts/backup/logs/`

Each backup creates a new log file with timestamp:
```
backup-data-20251110-123456.log
backup-nginx-20251110-134523.log
```

## Permission Details

**Backup root structure:**
```bash
/mnt/backup/backups/                   # drwxr-xr-x (755) - readable by all
└── usr/                               # drwxr-xr-x (755) - readable by all
    ├── administrator/                 # drwx------ (700) - admin only
    │   └── projects/                  # drwx------ (700) - admin only
    ├── websurfinmurf/                 # drwx------ (700) - websurfinmurf only
    ├── apprunner/                     # drwx------ (700) - apprunner only
    └── joe/                           # drwx------ (700) - joe only
```

**Ownership:**
- Each user owns their entire directory tree
- `chown -R username:username /mnt/backup/backups/usr/username`

**Security:**
- Users can see that other user directories exist (755 on /usr/)
- Users CANNOT read, write, or access other users' directories (700 on user dirs)
- Root can access all directories

## Unmounting the Drive

If you need to safely disconnect the USB drive:

```bash
sudo umount /mnt/backup
```

**Important:** Always unmount before physically removing to prevent data corruption.

## Troubleshooting

### Drive Not Auto-Mounted After Boot

**Check if drive is connected:**
```bash
lsblk | grep sda
```

**Check fstab entry:**
```bash
grep /dev/sda4 /etc/fstab
```

Should show:
```
/dev/sda4  /mnt/backup  ext4  defaults,nofail  0  2
```

**Try manual mount:**
```bash
sudo mount -a
```

### Backup Fails - Permission Denied

**Check your backup directory ownership:**
```bash
ls -ld /mnt/backup/backups/usr/$(whoami)
```

Should show your username as owner. If not:
```bash
sudo chown -R $(whoami):$(whoami) /mnt/backup/backups/usr/$(whoami)
```

### Backup Fails - Directory Not Found

Run the setup script again:
```bash
sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh
```

### Cannot Access Other User's Backups

This is **by design** for security. Each user can only access their own backups.

If you need to access another user's backup (as administrator):
```bash
# As root/sudo
sudo ls -la /mnt/backup/backups/usr/joe/projects/
```

### Space Issues

**Check available space:**
```bash
df -h /mnt/backup
```

**Check what's using space:**
```bash
sudo du -sh /mnt/backup/backups/usr/*/
```

**Check specific user's backups:**
```bash
du -sh /mnt/backup/backups/usr/$(whoami)/projects/*/
```

## Restoring From Backup

### Restore Entire Project

```bash
# Restore your data project
rsync -avh --delete \
  /mnt/backup/backups/usr/$(whoami)/projects/data/ \
  /home/$(whoami)/projects/data/
```

### Restore Specific Directory

```bash
# Restore just one subdirectory (e.g., arangodb)
rsync -avh \
  /mnt/backup/backups/usr/$(whoami)/projects/data/arangodb/ \
  /home/$(whoami)/projects/data/arangodb/
```

**Warning:** The `--delete` flag removes files in destination that don't exist in backup. Use carefully.

## Setting Up for Other Users

If other users (websurfinmurf, apprunner, joe) want to use backups:

### Step 1: Copy Backup Script to Their Home

```bash
# As the other user
mkdir -p ~/projects/devscripts/backup
cp /home/administrator/projects/devscripts/backup/backup-projects-data.sh ~/projects/devscripts/backup/
chmod +x ~/projects/devscripts/backup/backup-projects-data.sh
```

### Step 2: Run Backup

```bash
# As the other user
~/projects/devscripts/backup/backup-projects-data.sh data
```

The script automatically detects the current user and backs up to their directory.

## Files

- **`~/projects/devscripts/backup/setup-backup-mount.sh`**: One-time setup script (creates structure, adds to fstab)
- **`~/projects/devscripts/backup/backup-projects-data.sh`**: User backup script (run anytime)
- **`~/projects/devscripts/backup/BACKUP-README.md`**: This documentation
- **`~/projects/devscripts/backup/BACKUPS-VARIABLE.md`**: $BACKUPS variable documentation
- **`/etc/fstab`**: Contains auto-mount configuration
- **`/etc/profile.d/backups.sh`**: $BACKUPS environment variable
- **`~/projects/devscripts/backup/logs/`**: Backup logs

## Automated Backups (Optional)

### Add to User's Crontab

Each user can set up their own automated backups:

```bash
crontab -e
```

Add line for daily backups at 2 AM:
```
0 2 * * * /home/$(whoami)/projects/devscripts/backup/backup-projects-data.sh data >> ~/projects/devscripts/backup/logs/cron.log 2>&1
```

Different projects at different times:
```
0 2 * * * /home/$(whoami)/projects/devscripts/backup/backup-projects-data.sh data >> ~/projects/devscripts/backup/logs/cron.log 2>&1
0 3 * * * /home/$(whoami)/projects/devscripts/backup/backup-projects-data.sh nginx >> ~/projects/devscripts/backup/logs/cron.log 2>&1
```

## Summary

**Structure:** `/mnt/backup/backups/usr/{username}/projects/{projectname}/`

**Setup (once):** `sudo ~/projects/devscripts/backup/setup-backup-mount.sh`

**Usage:** `~/projects/devscripts/backup/backup-projects-data.sh [project-name] [--dry-run]`

**Auto-mount:** Configured in `/etc/fstab` - mounts on every boot

**Security:** Each user can only access their own backups (700 permissions)

**Logs:** `~/projects/devscripts/backup/logs/backup-{project}-{timestamp}.log`

---

**Created**: 2025-11-10
**Thumb Drive**: SanDisk 3.2Gen1 (454.3GB)
**Users**: administrator, websurfinmurf, apprunner, joe
**Mount Point**: `/mnt/backup`
**Auto-Mount**: Yes (via fstab)
