# $BACKUPS Environment Variable

## Overview

The `$BACKUPS` environment variable is automatically set for all users on login and points to their personal backup directory on the thumb drive.

**Location:** `/etc/profile.d/backups.sh`
**Auto-loaded:** Yes, on every user login
**Per-user:** Yes, uses `$USER` variable

## What It Contains

Each user gets their own path:

```bash
administrator: $BACKUPS = /mnt/backup/backups/usr/administrator/projects
websurfinmurf: $BACKUPS = /mnt/backup/backups/usr/websurfinmurf/projects
apprunner:     $BACKUPS = /mnt/backup/backups/usr/apprunner/projects
joe:           $BACKUPS = /mnt/backup/backups/usr/joe/projects
```

## Setup

The variable is automatically created when you run:

```bash
sudo /tmp/setup-backup-mount.sh
```

This creates `/etc/profile.d/backups.sh` with:

```bash
export BACKUPS="/mnt/backup/backups/usr/$USER/projects"
```

## Usage Examples

### Check Your Backup Path

```bash
echo $BACKUPS
# Output: /mnt/backup/backups/usr/administrator/projects
```

### List Your Backups

```bash
ls $BACKUPS
# Shows: data/ nginx/ mcp/ etc.
```

### Navigate to Backups

```bash
cd $BACKUPS
pwd
# /mnt/backup/backups/usr/administrator/projects
```

### Manual Backup Using Variable

```bash
# Backup a project
rsync -avh ~/projects/data/ $BACKUPS/data/

# Restore from backup
rsync -avh $BACKUPS/data/ ~/projects/data/
```

### Check Backup Size

```bash
du -sh $BACKUPS/*
# Shows size of each backed up project
```

### Find Files in Backups

```bash
find $BACKUPS -name "*.conf"
grep -r "search_term" $BACKUPS/
```

## Using in Scripts

The backup script automatically uses `$BACKUPS`:

```bash
#!/bin/bash
# Script automatically uses $BACKUPS if available
/home/administrator/projects/devscripts/backup/backup-projects-data.sh data
```

Your own scripts can use it too:

```bash
#!/bin/bash
# Custom backup script

if [ -z "$BACKUPS" ]; then
    echo "ERROR: \$BACKUPS not set"
    exit 1
fi

# Use the variable
rsync -avh ~/my-files/ $BACKUPS/my-files/
```

## Activate Without Re-Login

If you just ran the setup and want to use `$BACKUPS` immediately:

```bash
source /etc/profile.d/backups.sh
echo $BACKUPS
```

## Check If Variable Is Set

```bash
if [ -n "$BACKUPS" ]; then
    echo "BACKUPS is set to: $BACKUPS"
else
    echo "BACKUPS is not set"
fi
```

## Troubleshooting

### Variable Not Set After Setup

**Logout and login again:**
```bash
exit
# SSH back in
echo $BACKUPS
```

Or source the file manually:
```bash
source /etc/profile.d/backups.sh
```

### Check If File Exists

```bash
ls -l /etc/profile.d/backups.sh
cat /etc/profile.d/backups.sh
```

Should show:
```bash
export BACKUPS="/mnt/backup/backups/usr/$USER/projects"
```

### Variable Points to Wrong Location

Re-run setup:
```bash
sudo /tmp/setup-backup-mount.sh
```

Or edit manually:
```bash
sudo nano /etc/profile.d/backups.sh
```

## System-Wide vs User-Specific

**System-wide configuration:** `/etc/profile.d/backups.sh`
- Loaded for ALL users on login
- Uses `$USER` variable to make it per-user
- No need for per-user configuration

**Alternative (per-user in ~/.bashrc):**
You could also add to each user's `~/.bashrc`:
```bash
export BACKUPS="/mnt/backup/backups/usr/$USER/projects"
```

But the system-wide approach in `/etc/profile.d/` is cleaner.

## Integration with Backup Script

The backup script (`backup-projects-data.sh`) checks for `$BACKUPS`:

```bash
# Use $BACKUPS environment variable if set, otherwise construct path
if [ -n "$BACKUPS" ]; then
    BACKUP_BASE="$BACKUPS"
else
    BACKUP_BASE="/mnt/backup/backups/usr/$CURRENT_USER/projects"
fi
```

This means:
- ✅ If `$BACKUPS` is set: Uses it
- ✅ If `$BACKUPS` is not set: Falls back to hardcoded path
- ✅ Works either way

## Benefits

1. **Easier to type:** `$BACKUPS` vs `/mnt/backup/backups/usr/administrator/projects`
2. **Scripts are portable:** Work for all users without modification
3. **Centralized config:** Change mount point in one place
4. **Auto-personalized:** Each user gets their own path automatically
5. **Standard convention:** All users know where backups are

## Examples by User

### Administrator

```bash
administrator$ echo $BACKUPS
/mnt/backup/backups/usr/administrator/projects

administrator$ ls $BACKUPS
data  nginx  mcp  admin

administrator$ du -sh $BACKUPS
3.2G    /mnt/backup/backups/usr/administrator/projects
```

### Websurfinmurf

```bash
websurfinmurf$ echo $BACKUPS
/mnt/backup/backups/usr/websurfinmurf/projects

websurfinmurf$ ls $BACKUPS
(their backed up projects)
```

## Summary

**Variable:** `$BACKUPS`
**Set by:** `/etc/profile.d/backups.sh`
**When:** On every user login
**Points to:** `/mnt/backup/backups/usr/{username}/projects`
**Setup:** `sudo /tmp/setup-backup-mount.sh`
**Activate now:** `source /etc/profile.d/backups.sh`

---

**Created:** 2025-11-10
**System-wide:** Yes
**Auto-loading:** Yes
