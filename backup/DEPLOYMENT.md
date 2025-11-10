# Backup System Deployment Guide for AI

## Overview

This directory contains version-controlled backup system scripts that are designed to be used **directly from this location**. They do NOT need to be copied to other locations (except where explicitly noted).

**Directory:** `/home/administrator/projects/devscripts/backup/`
**Version Control:** This entire directory should be committed to git
**Purpose:** Centralized backup system configuration and scripts

## AI Instructions

### When Making Changes

1. **Always edit files in this directory:** `/home/administrator/projects/devscripts/backup/`
2. **Check the deployment header** at the top of each script for specific instructions
3. **Most scripts are used directly from this location** - no copying needed
4. **Only one file needs deployment** to system location (see below)

## Files and Their Deployment

### Scripts Used Directly (No Deployment Needed)

These scripts are executed from this directory. Users reference them with full paths.

#### 1. setup-backup-mount.sh
**Location:** `/home/administrator/projects/devscripts/backup/setup-backup-mount.sh`
**Deployment:** NONE - Run directly from source location
**Usage:** `sudo ~/projects/devscripts/backup/setup-backup-mount.sh`
**Purpose:** One-time setup (creates mount point, fstab entry, directories, permissions, env variable)
**AI Action:** Edit in place, no copying needed

#### 2. backup-projects-data.sh
**Location:** `/home/administrator/projects/devscripts/backup/backup-projects-data.sh`
**Deployment:** NONE - Run directly from source location
**Usage:** `~/projects/devscripts/backup/backup-projects-data.sh [project] [--dry-run]`
**Purpose:** Main backup script for user projects
**AI Action:** Edit in place, no copying needed

#### 3. setup-backup-env.sh
**Location:** `/home/administrator/projects/devscripts/backup/setup-backup-env.sh`
**Deployment:** NONE - Run directly from source location
**Usage:** `sudo ~/projects/devscripts/backup/setup-backup-env.sh`
**Purpose:** Standalone script to setup/update $BACKUPS environment variable
**AI Action:** Edit in place, no copying needed
**Note:** This is optional - setup-backup-mount.sh includes this functionality

#### 4. mount-backup-drive.sh (DEPRECATED)
**Location:** `/home/administrator/projects/devscripts/backup/mount-backup-drive.sh`
**Deployment:** NONE - Run directly from source location
**Usage:** `sudo ~/projects/devscripts/backup/mount-backup-drive.sh`
**Purpose:** Legacy manual mount script (replaced by fstab auto-mount)
**AI Action:** Edit in place if needed, but prefer setup-backup-mount.sh

### Template Files (Deployed by Setup Scripts)

#### 5. backups.sh.template
**Source Location:** `/home/administrator/projects/devscripts/backup/backups.sh.template`
**Deploy Location:** `/etc/profile.d/backups.sh`
**Deployment Method:** Automatic (by setup-backup-mount.sh or setup-backup-env.sh)
**Manual Deployment:**
```bash
sudo cp ~/projects/devscripts/backup/backups.sh.template /etc/profile.d/backups.sh
sudo chmod +x /etc/profile.d/backups.sh
```
**AI Action:**
1. Edit `backups.sh.template` in this directory
2. User runs `sudo ~/projects/devscripts/backup/setup-backup-env.sh` to deploy
3. OR AI can deploy manually with the commands above

**Purpose:** Sets $BACKUPS environment variable for all users

### Documentation Files (No Deployment)

#### 6. BACKUP-README.md
**Location:** `/home/administrator/projects/devscripts/backup/BACKUP-README.md`
**Deployment:** NONE - Read from source location
**Purpose:** User-facing documentation
**AI Action:** Edit in place, no copying needed

#### 7. BACKUPS-VARIABLE.md
**Location:** `/home/administrator/projects/devscripts/backup/BACKUPS-VARIABLE.md`
**Deployment:** NONE - Read from source location
**Purpose:** $BACKUPS variable documentation
**AI Action:** Edit in place, no copying needed

#### 8. CLAUDE.md
**Location:** `/home/administrator/projects/devscripts/backup/CLAUDE.md`
**Deployment:** NONE - Read from source location
**Purpose:** Project context for AI
**AI Action:** Edit in place, no copying needed

#### 9. DEPLOYMENT.md (This File)
**Location:** `/home/administrator/projects/devscripts/backup/DEPLOYMENT.md`
**Deployment:** NONE - Read from source location
**Purpose:** AI deployment instructions
**AI Action:** Edit in place, no copying needed

## Workflow for AI

### Scenario 1: User Asks to Modify Backup Script Logic

1. Read `/home/administrator/projects/devscripts/backup/backup-projects-data.sh`
2. Make changes to that file
3. Done! No copying needed - script is used from this location

### Scenario 2: User Asks to Change $BACKUPS Variable Path

1. Read `/home/administrator/projects/devscripts/backup/backups.sh.template`
2. Make changes to the template
3. Tell user to run: `sudo ~/projects/devscripts/backup/setup-backup-env.sh`
4. This deploys the updated template to `/etc/profile.d/backups.sh`

### Scenario 3: User Asks to Add New User to Backup System

1. Read `/home/administrator/projects/devscripts/backup/setup-backup-mount.sh`
2. Add new user to `USERS=()` array
3. Tell user to run: `sudo ~/projects/devscripts/backup/setup-backup-mount.sh`
4. Script will create directory structure for new user

### Scenario 4: User Asks to Change Backup Device

1. Read `/home/administrator/projects/devscripts/backup/setup-backup-mount.sh`
2. Modify `DEVICE="/dev/sda4"` variable
3. Tell user to run: `sudo ~/projects/devscripts/backup/setup-backup-mount.sh`

### Scenario 5: User Asks to Update Documentation

1. Read the relevant `.md` file in `/home/administrator/projects/devscripts/backup/`
2. Make changes
3. Done! No copying needed - documentation lives here

## System Files Created by Setup Scripts

These files are NOT in version control. They are created by the setup scripts.

### Created by setup-backup-mount.sh:

1. **`/mnt/backup`** - Mount point directory
2. **`/etc/fstab`** - Entry added: `/dev/sda4  /mnt/backup  ext4  defaults,nofail  0  2`
3. **`/mnt/backup/backups/usr/{username}/projects/`** - Multi-user directory structure
4. **`/etc/profile.d/backups.sh`** - $BACKUPS environment variable (from template)

### Created by backup-projects-data.sh:

1. **`~/projects/devscripts/backup/logs/`** - Backup log directory
2. **`~/projects/devscripts/backup/logs/backup-{project}-{timestamp}.log`** - Individual backup logs
3. **`/mnt/backup/backups/usr/{username}/projects/{projectname}/.last-backup`** - Timestamp files

## Directory Structure

```
/home/administrator/projects/devscripts/backup/
├── setup-backup-mount.sh      # Main setup script (use directly)
├── setup-backup-env.sh         # Env var setup (use directly)
├── backup-projects-data.sh     # Main backup script (use directly)
├── mount-backup-drive.sh       # Legacy mount (use directly, deprecated)
├── backups.sh.template         # Template → deployed to /etc/profile.d/
├── BACKUP-README.md            # User documentation (reference here)
├── BACKUPS-VARIABLE.md         # $BACKUPS docs (reference here)
├── CLAUDE.md                   # Project context (reference here)
├── DEPLOYMENT.md               # This file (reference here)
└── logs/                       # Created at runtime (not in git)
    └── backup-*.log            # Backup logs (not in git)
```

## Git Ignore Recommendations

Add to `.gitignore` in this directory:

```gitignore
# Runtime logs (not configuration)
logs/
*.log
```

## Quick Reference for AI

| Task | Action |
|------|--------|
| Modify backup logic | Edit `backup-projects-data.sh` in place |
| Add new user | Edit `setup-backup-mount.sh` USERS array, user runs script |
| Change $BACKUPS path | Edit `backups.sh.template`, user runs `setup-backup-env.sh` |
| Update docs | Edit `.md` files in place |
| Change device | Edit `setup-backup-mount.sh` DEVICE variable, user runs script |

## Summary

**Key Concept:** This is a "run-from-source" backup system. Scripts live in version control and are executed directly from this location. Only the environment variable template gets deployed to `/etc/profile.d/`, and that's done automatically by the setup scripts.

**AI Best Practice:**
1. Always edit files in `/home/administrator/projects/devscripts/backup/`
2. Check deployment header in each file for specific instructions
3. Most changes require NO manual deployment - just edit in place
4. Only `backups.sh.template` → `/etc/profile.d/backups.sh` needs deployment, and setup scripts do it automatically

---

**Created:** 2025-11-10
**Purpose:** AI deployment instructions for backup system
**Location:** `/home/administrator/projects/devscripts/backup/DEPLOYMENT.md`
