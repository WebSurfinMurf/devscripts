# Backup System - Multi-User Project Backups

> **For overall environment context, see: `/home/administrator/projects/CLAUDE.md`**

## Project Overview

Multi-user backup system for project data to external USB thumb drive with auto-mount on boot.

**Location:** `/home/administrator/projects/devscripts/backup/`
**Thumb Drive:** SanDisk 3.2Gen1 (454.3GB) - `/dev/sda4` → `/mnt/backup`
**Structure:** `/mnt/backup/backups/usr/{username}/projects/{projectname}/`

## Files

- **setup-backup-mount.sh** - One-time setup (mount + fstab + directories + permissions + $BACKUPS variable)
- **backup-projects-data.sh** - Main backup script (rsync-based, per-user, per-project)
- **mount-backup-drive.sh** - Manual mount script (deprecated, setup script preferred)
- **BACKUP-README.md** - Complete user documentation
- **BACKUPS-VARIABLE.md** - $BACKUPS environment variable documentation
- **logs/** - Backup operation logs (auto-created)

## Quick Start

### Initial Setup (Run Once)

```bash
sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh
```

This creates:
- Mount point: `/mnt/backup`
- fstab entry: Auto-mount on boot
- Directory structure: `/mnt/backup/backups/usr/{user}/projects/`
- Permissions: 700 per user (user-only access)
- Environment variable: `$BACKUPS` in `/etc/profile.d/backups.sh`

### Usage

```bash
# Backup 'data' project (default)
~/projects/devscripts/backup/backup-projects-data.sh

# Backup specific project
~/projects/devscripts/backup/backup-projects-data.sh nginx

# Dry run
~/projects/devscripts/backup/backup-projects-data.sh data --dry-run
```

## Features

- ✅ **Auto-mount on boot** - Drive mounts automatically via `/etc/fstab`
- ✅ **Multi-user support** - administrator, websurfinmurf, apprunner, joe
- ✅ **User isolation** - 700 permissions, users can't access others' backups
- ✅ **Project selection** - Backup any project by name
- ✅ **Incremental backups** - rsync only copies changed files
- ✅ **$BACKUPS variable** - `/mnt/backup/backups/usr/$USER/projects` auto-set on login
- ✅ **Comprehensive logging** - All operations logged to `logs/` directory
- ✅ **Safety checks** - Verifies mount, permissions, space before backup
- ✅ **Delete sync** - Removes files from backup that were deleted from source
- ✅ **Progress display** - Real-time transfer progress

## Architecture

### Directory Structure

```
/mnt/backup/backups/usr/
├── administrator/
│   └── projects/
│       ├── data/          # Backup of ~/projects/data/
│       ├── nginx/         # Backup of ~/projects/nginx/
│       └── [...]
├── websurfinmurf/
│   └── projects/
├── apprunner/
│   └── projects/
└── joe/
    └── projects/
```

### Permissions

```bash
/mnt/backup/backups/           # 755 (drwxr-xr-x) - readable by all
└── usr/                       # 755 (drwxr-xr-x) - readable by all
    └── administrator/         # 700 (drwx------) - admin only
        └── projects/          # 700 (drwx------) - admin only
            └── data/          # Owned by admin, full backup
```

### Environment Variable

**File:** `/etc/profile.d/backups.sh`
**Content:** `export BACKUPS="/mnt/backup/backups/usr/$USER/projects"`
**Per-User Values:**
- administrator: `/mnt/backup/backups/usr/administrator/projects`
- websurfinmurf: `/mnt/backup/backups/usr/websurfinmurf/projects`
- apprunner: `/mnt/backup/backups/usr/apprunner/projects`
- joe: `/mnt/backup/backups/usr/joe/projects`

### Auto-Mount Configuration

**File:** `/etc/fstab`
**Entry:** `/dev/sda4  /mnt/backup  ext4  defaults,nofail  0  2`
**Options:**
- `defaults` - Standard mount options
- `nofail` - System boots even if drive disconnected
- Auto-mounts on every boot

## Workflow

### Setup Flow

1. User runs `sudo setup-backup-mount.sh`
2. Script creates `/mnt/backup` mount point
3. Script adds fstab entry for auto-mount
4. Script mounts drive immediately
5. Script creates multi-user directory structure
6. Script sets 700 permissions on each user directory
7. Script creates `/etc/profile.d/backups.sh` for `$BACKUPS` variable
8. Done - drive auto-mounts on future boots

### Backup Flow

1. User runs `backup-projects-data.sh [project-name]`
2. Script detects current user (`$USER`)
3. Script checks if `$BACKUPS` is set, uses it (or constructs path)
4. Script verifies source exists (`~/projects/{project-name}`)
5. Script checks backup drive is mounted
6. Script verifies user has write access to backup directory
7. Script checks available space
8. Script runs `rsync -avh --delete --progress`
9. Script creates `.last-backup` timestamp file
10. Script logs all operations to `logs/backup-{project}-{timestamp}.log`

## Recent Work & Changes

### Session: 2025-11-10

**Created complete multi-user backup system:**
- Thumb drive setup with auto-mount on boot
- Multi-user directory structure with proper isolation
- $BACKUPS environment variable for easy access
- Comprehensive backup script with logging
- Complete documentation (README + VARIABLE guide)

**Relocated to devscripts/backup:**
- Moved from `~/scripts/` to `~/projects/devscripts/backup/`
- Updated all script references and paths
- Updated log directory to `~/projects/devscripts/backup/logs/`
- Updated all documentation with new paths
- Created CLAUDE.md for project context

## Users Configured

- **administrator** - Main system administrator
- **websurfinmurf** - Secondary user
- **apprunner** - Application runner user
- **joe** - Standard user

Each user gets their own isolated backup directory with 700 permissions.

## Common Commands

```bash
# Setup (once)
sudo ~/projects/devscripts/backup/setup-backup-mount.sh

# Backup data project
~/projects/devscripts/backup/backup-projects-data.sh data

# Backup specific project
~/projects/devscripts/backup/backup-projects-data.sh nginx

# Dry run test
~/projects/devscripts/backup/backup-projects-data.sh data --dry-run

# Check backups
ls -lh $BACKUPS
du -sh $BACKUPS/*

# View logs
ls -lh ~/projects/devscripts/backup/logs/
tail -f ~/projects/devscripts/backup/logs/backup-data-*.log
```

## Troubleshooting

### Drive Not Mounted

```bash
# Check if connected
lsblk | grep sda

# Check fstab
grep /dev/sda4 /etc/fstab

# Manual mount
sudo mount -a
```

### Permission Denied

```bash
# Check ownership
ls -ld $BACKUPS

# Fix if needed
sudo chown -R $(whoami):$(whoami) $BACKUPS
```

### $BACKUPS Not Set

```bash
# Check file exists
cat /etc/profile.d/backups.sh

# Activate now
source /etc/profile.d/backups.sh

# Or logout and login again
```

## Integration

**Other Users Setup:**
```bash
# As other user (websurfinmurf, apprunner, joe)
mkdir -p ~/projects/devscripts/backup
cp /home/administrator/projects/devscripts/backup/backup-projects-data.sh ~/projects/devscripts/backup/
chmod +x ~/projects/devscripts/backup/backup-projects-data.sh

# Run backup
~/projects/devscripts/backup/backup-projects-data.sh data
```

**Automated Backups (Optional):**
```bash
crontab -e

# Daily at 2 AM
0 2 * * * ~/projects/devscripts/backup/backup-projects-data.sh data >> ~/projects/devscripts/backup/logs/cron.log 2>&1
```

## Notes

- First backup takes longest (copies all ~3GB)
- Subsequent backups are incremental (only changed files)
- Drive has 454GB available (plenty of space)
- Logs are kept indefinitely (can clean manually)
- Each user backs up to their own isolated directory
- Root can access all user backups for recovery

## Known Issues

None currently.

## TODOs

- [ ] Consider adding backup rotation/retention policy
- [ ] Consider adding backup verification checks
- [ ] Consider adding email notifications on backup completion/failure

---

**Created:** 2025-11-10
**Location:** `/home/administrator/projects/devscripts/backup/`
**Auto-Mount:** Yes (via /etc/fstab)
**Multi-User:** Yes (4 users configured)
