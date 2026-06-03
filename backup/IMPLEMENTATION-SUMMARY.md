# Automated Backup System - Implementation Summary

## What's Been Implemented

### 1. Environment Variables (Two-Tier Design)

**File:** `backups.sh.template` → deploys to `/etc/profile.d/backups.sh`

```bash
export BACKUPROOT="/mnt/backup/backups/usr"           # System-wide root
export BACKUPS="$BACKUPROOT/$USER"                     # Per-user root
```

**Resolution for administrator user:**
- `$BACKUPROOT` = `/mnt/backup/backups/usr`
- `$BACKUPS` = `/mnt/backup/backups/usr/administrator`

**Usage:**
- System scripts use `$BACKUPROOT` to iterate over all users
- Users reference `$BACKUPS` for their own backup root
- Logs at: `$BACKUPS/backup.log`
- Project backups at: `$BACKUPS/projects/{projectname}/`

### 2. Automated Backup Script with Rotation

**File:** `backup-projects-data.sh`

**Features:**
- ✅ Runs system-wide (processes all 4 users)
- ✅ Backs up `~/projects/data/` for each user (if exists)
- ✅ Creates compressed tar.gz archives
- ✅ Three-tier retention: Daily, Weekly (Saturday), Monthly (1st Saturday)
- ✅ Automatic rotation: Deletes old backups beyond retention limits
- ✅ Comprehensive logging to `$BACKUPS/backup.log`
- ✅ Skips users without `data` directory (no failure)
- ✅ Proper file ownership (each user owns their backups)

**Retention Policy** (authoritative source: top of `backup-projects-data.sh`):
| Type | Kept | When Created | Filename Pattern |
|------|------|--------------|------------------|
| Daily | 3 | Every run | `data-daily-YYYY-MM-DD.tar.gz` |
| Weekly | 1 | Saturdays | `data-weekly-YYYY-MM-DD.tar.gz` |
| Monthly | 1 | 1st Saturday | `data-monthly-YYYY-MM-DD.tar.gz` |

**Backup Logic:**
1. Check if `~/projects/data/` exists → Skip if not
2. Create daily backup (always) — stage to NVMe, verify, copy to USB
3. Promote daily to weekly via hardlink (if Saturday) — `ln daily weekly`, zero extra bytes
4. Promote daily to monthly via hardlink (if 1st Saturday of month) — same pattern
5. Rotate old backups (delete excess beyond retention; underlying data persists as long as any hardlink survives)
6. Log everything to `$BACKUPS/backup.log`

### 3. Cron Job System

**Files:**
- `backup-cron.template` - Cron job configuration
- `enable-cron.sh` - Helper script to deploy cron job

**Schedule:** Daily at 4:00 AM
**Runs as:** root (system-wide, processes all users)
**Log:** `/var/log/backup-cron.log`

**Cron Entry:**
```
0 4 * * * root /home/administrator/projects/devscripts/backup/backup-projects-data.sh >> /var/log/backup-cron.log 2>&1
```

### 4. Directory Structure

```
/mnt/backup/backups/usr/
└── administrator/                                    # $BACKUPS for administrator
    ├── backup.log                                    # User's comprehensive log
    └── projects/
        └── data/
            ├── data-daily-2026-05-30.tar.gz         # Today
            ├── data-daily-2026-05-29.tar.gz
            ├── data-daily-2026-05-28.tar.gz         # 3 daily total
            ├── data-weekly-2026-05-23.tar.gz        # 1 weekly (hardlinked to the daily it was promoted from, until that daily rotates out)
            └── data-monthly-2026-05-02.tar.gz       # 1 monthly (same hardlink mechanic)
```

## Testing Steps

### Step 1: Deploy Environment Variables

```bash
# Run the setup script to deploy backups.sh to /etc/profile.d/
sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh

# Or just deploy the env variables:
sudo /home/administrator/projects/devscripts/backup/setup-backup-env.sh

# Activate in current session
source /etc/profile.d/backups.sh

# Verify
echo $BACKUPROOT
# Should show: /mnt/backup/backups/usr

echo $BACKUPS
# Should show: /mnt/backup/backups/usr/administrator
```

### Step 2: Test Manual Backup (DO THIS FIRST)

```bash
# Run backup script manually as root
sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh

# Watch the output - should show:
#  - Which users have data directories
#  - Backup creation progress
#  - Compression progress
#  - Rotation activity
#  - Summary for each user
```

**Expected Output:**
```
=== Automated Backup System ===
Date: 2025-11-10
Day of week: 7 (Saturday=false)
First Saturday: false
Backup types: Daily

--- Processing user: administrator ---
  Source: /home/administrator/projects/data (3.0G)
  Destination: /mnt/backup/backups/usr/administrator/projects/data
  → Creating daily backup...
    ✓ Daily backup created: 1.0G
  → Rotating old backups...
    Daily: 1 found (keeping all)
  ✓ Backup complete for administrator
    Backups created: 1
    Backups deleted: 0
    Total backups: 1
    Backup directory size: 1.0G

--- Processing user: websurfinmurf ---
  ⊘ Skipping: /home/websurfinmurf/projects/data does not exist

... (similar for other users)
```

### Step 3: Verify Backup Files

```bash
# Check backup files created
ls -lh $BACKUPS/projects/data/

# Check log
cat $BACKUPS/backup.log

# Verify file ownership
ls -l $BACKUPS/projects/data/*.tar.gz
# Should show: administrator administrator
```

### Step 4: Test Restore

```bash
# List archive contents
tar -tzf $BACKUPS/projects/data/data-daily-2025-11-10.tar.gz | head -20

# Test restore to temp location
mkdir /tmp/restore-test
cd /tmp/restore-test
tar -xzf $BACKUPS/projects/data/data-daily-2025-11-10.tar.gz

# Verify contents
ls -la data/
```

### Step 5: Enable Automated Cron Job (AFTER SUCCESSFUL MANUAL TEST)

```bash
# Deploy cron job
sudo /home/administrator/projects/devscripts/backup/enable-cron.sh

# Verify cron job installed
sudo cat /etc/cron.d/backup-projects
```

## Storage Estimates

**Per-User Estimates (administrator with current ~95 GB data):**
- Source: `~/projects/data/` ≈ 95 GB
- Compressed (tar.gz): ~81 GB (~85% retained)
- Retention: 3 daily + 1 weekly + 1 monthly = up to 5 inodes, weekly/monthly often hardlinked into a daily so real disk is 3–5 inodes' worth
- Max real storage per user: ~5 × 81 GB ≈ 405 GB worst case; typical ~243–324 GB

**Total for 4 Users:**
- If all users have 3GB data: ~68GB total
- Available on thumb drive: 454GB
- Usage: ~15% of drive capacity

## Log File Format

**Location:** `$BACKUPS/backup.log`

**Sample Entries:**
```
========================================
Backup started: 2025-11-10 04:00:01
User: administrator
Source: /home/administrator/projects/data (3.0G)
========================================
2025-11-10 04:00:15 - DAILY - Created: data-daily-2025-11-10.tar.gz (1.0G)
Backups created: 1
Backups deleted: 0
Total backups: 7
Backup directory size: 7.0G
Status: SUCCESS
Backup completed: 2025-11-10 04:00:45
```

## Restore Procedures

### Restore Entire Project

```bash
# Navigate to home directory
cd ~

# Restore from backup (this will overwrite existing data!)
tar -xzf $BACKUPS/projects/data/data-daily-2025-11-10.tar.gz -C projects/

# Or restore specific backup type
tar -xzf $BACKUPS/projects/data/data-weekly-2025-11-09.tar.gz -C projects/
tar -xzf $BACKUPS/projects/data/data-monthly-2025-11-02.tar.gz -C projects/
```

### Restore Specific File

```bash
# List files in archive
tar -tzf $BACKUPS/projects/data/data-daily-2025-11-10.tar.gz

# Extract specific file
tar -xzf $BACKUPS/projects/data/data-daily-2025-11-10.tar.gz data/specific-file.txt

# File will be extracted to: ./data/specific-file.txt
```

### Restore to Different Location

```bash
# Extract to /tmp for inspection
mkdir /tmp/restore-check
tar -xzf $BACKUPS/projects/data/data-daily-2025-11-10.tar.gz -C /tmp/restore-check/

# Review contents
ls -la /tmp/restore-check/data/
```

## Monitoring

### Check Backup Status

```bash
# View recent log entries
tail -50 $BACKUPS/backup.log

# Check cron execution log
sudo tail -50 /var/log/backup-cron.log

# List all backups
ls -lh $BACKUPS/projects/data/

# Check backup sizes
du -sh $BACKUPS/projects/data/*.tar.gz
```

### Verify Rotation Working

```bash
# Count daily backups (should be max 7)
ls -1 $BACKUPS/projects/data/data-daily-*.tar.gz | wc -l

# Count weekly backups (should be max 1)
ls -1 $BACKUPS/projects/data/data-weekly-*.tar.gz | wc -l

# Count monthly backups (should be max 1)
ls -1 $BACKUPS/projects/data/data-monthly-*.tar.gz | wc -l
```

## Troubleshooting

### Cron Job Not Running

```bash
# Check if cron service is running
sudo systemctl status cron

# Check cron job file exists
sudo cat /etc/cron.d/backup-projects

# Check cron log
sudo tail -100 /var/log/backup-cron.log

# Check system log for cron
sudo grep CRON /var/log/syslog | tail -20
```

### Backups Not Being Created

```bash
# Run manually to see errors
sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh

# Check if drive is mounted
mount | grep /mnt/backup

# Check if data directory exists
ls -ld ~/projects/data/

# Check environment variables
source /etc/profile.d/backups.sh
echo $BACKUPROOT
echo $BACKUPS
```

### Permission Errors

```bash
# Check backup directory ownership
ls -ld $BACKUPROOT/administrator

# Should show: drwx------ administrator administrator

# Fix if needed
sudo chown -R administrator:administrator $BACKUPROOT/administrator
sudo chmod 700 $BACKUPROOT/administrator
```

## Files Summary

| File | Purpose | Deployment |
|------|---------|------------|
| `backups.sh.template` | Env variables template | → `/etc/profile.d/backups.sh` |
| `backup-projects-data.sh` | Main backup script | Used from source location |
| `backup-cron.template` | Cron job template | → `/etc/cron.d/backup-projects` |
| `enable-cron.sh` | Cron deployment helper | Used from source location |
| `setup-backup-mount.sh` | Initial setup | Used from source location |
| `setup-backup-env.sh` | Env var setup | Used from source location |

## Next Steps

1. ✅ **Test manually first** - Run `sudo backup-projects-data.sh` and verify it works
2. ⏸️ **Deploy environment variables** - Run `sudo setup-backup-env.sh` if not done
3. ⏸️ **Enable cron job** - Run `sudo enable-cron.sh` after successful manual test
4. ⏸️ **Monitor first automated run** - Check logs after 4 AM next day
5. ⏸️ **Verify rotation** - After 8 days, verify only 7 daily backups kept

---

**Created:** 2025-11-10
**Status:** Ready for testing
**Test Command:** `sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh`
