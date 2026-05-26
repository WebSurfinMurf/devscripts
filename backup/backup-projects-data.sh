#!/bin/bash
################################################################################
# DEPLOYMENT INSTRUCTIONS FOR AI
################################################################################
# This is the VERSION-CONTROLLED source file.
#
# Location: /home/administrator/projects/devscripts/backup/backup-projects-data.sh
#
# When making changes:
# 1. Edit THIS file (the one in projects/devscripts/backup/)
# 2. This script is used directly from this location - no copying needed
# 3. Can be run manually or via cron (system-wide as root)
#
# Manual Usage: sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh
# Cron Usage: 0 4 * * * /home/administrator/projects/devscripts/backup/backup-projects-data.sh
################################################################################

# Automated backup system with rotation
# - Backs up ~/projects/data/ for all users (if exists)
# - Creates tar.gz compressed archives
# - Retention: 7 daily, 4 weekly (Sat), 6 monthly (1st Sat)
# - Logs to $BACKUPROOT/{username}/backup.log

set -eo pipefail

# Source environment variables if not set
if [ -z "$BACKUPROOT" ]; then
    if [ -f /etc/profile.d/backups.sh ]; then
        source /etc/profile.d/backups.sh
    else
        echo "ERROR: BACKUPROOT not set and /etc/profile.d/backups.sh not found"
        echo "Run setup script: sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh"
        exit 1
    fi
fi

# Configuration
# Retention sized for ~78 GB/archive on a 447 GB /mnt/backup volume.
# 3 + 1 + 1 = 5 archives × 78 GB ≈ 390 GB (≈ 57 GB headroom). See
# admin/backups/docs/context/invariants.md (I4) for the capacity math.
PROJECT_NAME="data"
RETENTION_DAILY=3
RETENTION_WEEKLY=1
RETENTION_MONTHLY=1

# Date calculations
TODAY=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)  # 1=Monday, 6=Saturday, 7=Sunday
DAY_OF_MONTH=$(date +%d)

# Determine if this is Saturday (6)
IS_SATURDAY=false
if [ "$DAY_OF_WEEK" -eq 6 ]; then
    IS_SATURDAY=true
fi

# Determine if this is first Saturday of month
IS_FIRST_SATURDAY=false
if [ "$IS_SATURDAY" = true ] && [ "$DAY_OF_MONTH" -le 7 ]; then
    IS_FIRST_SATURDAY=true
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Users to process
USERS=("administrator" "websurfinmurf" "apprunner" "joe")

echo -e "${BLUE}=== Automated Backup System ===${NC}"
echo "Date: $TODAY"
echo "Day of week: $DAY_OF_WEEK (Saturday=$IS_SATURDAY)"
echo "First Saturday: $IS_FIRST_SATURDAY"
echo "Backup types: Daily$([ "$IS_SATURDAY" = true ] && echo ", Weekly")$([ "$IS_FIRST_SATURDAY" = true ] && echo ", Monthly")"
echo ""

# PRE-BACKUP: Force database saves to disk
echo -e "${BLUE}=== Pre-Backup: Forcing database saves to disk ===${NC}"
SAVE_SCRIPTS=(
    "/home/administrator/projects/postgres/manualsavealldb.sh"
    "/home/administrator/projects/timescaledb/manualsavealldb.sh"
    "/home/administrator/projects/redis/manualsavealldb.sh"
    "/home/administrator/projects/mongodb/manualsavealldb.sh"
    "/home/administrator/projects/qdrant/manualsavealldb.sh"
    "/home/administrator/projects/arangodb/manualsavealldb.sh"
)

for SAVE_SCRIPT in "${SAVE_SCRIPTS[@]}"; do
    if [ -x "$SAVE_SCRIPT" ]; then
        echo -e "${BLUE}Running: $(basename $(dirname $SAVE_SCRIPT))/$(basename $SAVE_SCRIPT)${NC}"
        if bash "$SAVE_SCRIPT" 2>&1; then
            echo -e "${GREEN}✓ Database save completed${NC}"
        else
            echo -e "${YELLOW}⚠ Database save failed (non-critical, continuing)${NC}"
        fi
        echo ""
    fi
done

echo -e "${GREEN}=== All database saves completed ===${NC}"
echo ""

# Process each user
for USERNAME in "${USERS[@]}"; do
    echo -e "${BLUE}--- Processing user: $USERNAME ---${NC}"

    # User paths
    USER_HOME="/home/$USERNAME"
    SOURCE_DIR="$USER_HOME/projects/$PROJECT_NAME"
    USER_BACKUP_ROOT="$BACKUPROOT/$USERNAME"
    BACKUP_DIR="$USER_BACKUP_ROOT/projects/$PROJECT_NAME"
    LOG_FILE="$USER_BACKUP_ROOT/backup.log"
    USER_GROUP=$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")

    # Check if source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${YELLOW}  ⊘ Skipping: $SOURCE_DIR does not exist${NC}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SKIP - $SOURCE_DIR does not exist" >> "$LOG_FILE" 2>/dev/null || true
        echo ""
        continue
    fi

    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}  ! Creating backup directory: $BACKUP_DIR${NC}"
        mkdir -p "$BACKUP_DIR"
        chown -R "$USERNAME:$USER_GROUP" "$USER_BACKUP_ROOT"
    fi

    # Calculate source size
    SOURCE_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | cut -f1)
    echo "  Source: $SOURCE_DIR ($SOURCE_SIZE)"
    echo "  Destination: $BACKUP_DIR"

    # Start logging
    {
        echo ""
        echo "========================================"
        echo "Backup started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "User: $USERNAME"
        echo "Source: $SOURCE_DIR ($SOURCE_SIZE)"
        echo "========================================"
    } >> "$LOG_FILE"

    # Create backups based on schedule
    BACKUPS_CREATED=0

    # Exclusions applied to all backups:
    # - data/netdata/cache/*.db* : Runtime metadata cache (auto-regenerated, ~656MB)
    # - data/volume-backups/* : Old nested backups (backups inside backups, ~235MB)
    # - data/mongodb/journal/* : MongoDB WAL files (ephemeral, ~315MB)
    # - data/gitlab/logs/*.log : GitLab logs (growing continuously, ~100MB+)

    # 1. DAILY BACKUP (always) — stage to NVMe, verify locally, copy to USB
    DAILY_FILE="$BACKUP_DIR/${PROJECT_NAME}-daily-${TODAY}.tar.gz"
    LOCAL_DIR="/var/tmp/backup-staging/$USERNAME/projects/$PROJECT_NAME"
    LOCAL_FILE="$LOCAL_DIR/${PROJECT_NAME}-daily.tar.gz"
    if [ ! -f "$DAILY_FILE" ]; then
        echo -e "${GREEN}  → Creating daily backup (NVMe stage → verify → copy to USB)...${NC}"

        # Ensure local staging dir exists; wipe any prior local copy + stale quarantines
        mkdir -p "$LOCAL_DIR"
        chown -R "$USERNAME:$USER_GROUP" "/var/tmp/backup-staging/$USERNAME" 2>/dev/null || true
        rm -f "$LOCAL_FILE" "$LOCAL_DIR/${PROJECT_NAME}-daily.tar.gz.failed."* 2>/dev/null || true

        # tar can exit non-zero on benign "file changed as we read it" warnings under
        # live snapshot (postgres WAL, loki chunks, mongo diagnostic). Don't trust its
        # exit code — validate the archive structurally afterwards instead.
        tar -czf "$LOCAL_FILE" -C "$USER_HOME/projects" \
            --exclude='data/netdata/cache/*.db*' \
            --exclude='data/volume-backups/*' \
            --exclude='data/mongodb/journal/*' \
            --exclude='data/gitlab/logs/*.log' \
            "$PROJECT_NAME" 2>&1 | tee -a "$LOG_FILE" || true

        if [ -s "$LOCAL_FILE" ] \
           && gzip -t "$LOCAL_FILE" 2>/dev/null \
           && tar -tzf "$LOCAL_FILE" >/dev/null 2>&1; then
            # Local archive verified on NVMe. Copy to USB and re-check size.
            LOCAL_SIZE_HUMAN=$(du -sh "$LOCAL_FILE" | cut -f1)
            echo -e "${GREEN}    ✓ Local archive verified ($LOCAL_SIZE_HUMAN); copying to USB...${NC}"
            if cp "$LOCAL_FILE" "$DAILY_FILE" && sync \
               && [ "$(stat -c %s "$LOCAL_FILE")" = "$(stat -c %s "$DAILY_FILE")" ]; then
                BACKUP_SIZE=$(du -sh "$DAILY_FILE" | cut -f1)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - DAILY - Created: $(basename "$DAILY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
                echo -e "${GREEN}    ✓ Daily backup on USB: $BACKUP_SIZE${NC}"
                BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
                chown "$USERNAME:$USER_GROUP" "$LOCAL_FILE" "$DAILY_FILE"
            else
                # Local archive is good; USB copy failed or truncated. Keep local, quarantine USB partial.
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - USB copy failed or size mismatch; quarantining USB partial. Local copy preserved at $LOCAL_FILE" >> "$LOG_FILE"
                echo -e "${RED}    ✗ USB copy failed; quarantining USB partial. Local copy retained at $LOCAL_FILE${NC}"
                mv -f "$DAILY_FILE" "${DAILY_FILE}.failed.$(date +%s)" 2>/dev/null || rm -f "$DAILY_FILE"
                chown "$USERNAME:$USER_GROUP" "$LOCAL_FILE" 2>/dev/null || true
            fi
        else
            # Local archive failed verification — quarantine local, don't touch USB.
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Local archive missing or fails gzip/tar verify; quarantining as .failed" >> "$LOG_FILE"
            echo -e "${RED}    ✗ Local archive failed verification; quarantining as .failed${NC}"
            mv -f "$LOCAL_FILE" "${LOCAL_FILE}.failed.$(date +%s)" 2>/dev/null || rm -f "$LOCAL_FILE"
        fi
    else
        echo -e "${YELLOW}    ⊙ Daily backup already exists${NC}"
    fi

    # 2. WEEKLY BACKUP (Saturdays only)
    if [ "$IS_SATURDAY" = true ]; then
        WEEKLY_FILE="$BACKUP_DIR/${PROJECT_NAME}-weekly-${TODAY}.tar.gz"
        if [ ! -f "$WEEKLY_FILE" ]; then
            echo -e "${GREEN}  → Creating weekly backup...${NC}"
            tar -czf "$WEEKLY_FILE" -C "$USER_HOME/projects" \
                --exclude='data/netdata/cache/*.db*' \
                --exclude='data/volume-backups/*' \
                --exclude='data/mongodb/journal/*' \
                --exclude='data/gitlab/logs/*.log' \
                "$PROJECT_NAME" 2>&1 | tee -a "$LOG_FILE" || true
            if [ -s "$WEEKLY_FILE" ] \
               && gzip -t "$WEEKLY_FILE" 2>/dev/null \
               && tar -tzf "$WEEKLY_FILE" >/dev/null 2>&1; then
                BACKUP_SIZE=$(du -sh "$WEEKLY_FILE" | cut -f1)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - WEEKLY - Created: $(basename "$WEEKLY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
                echo -e "${GREEN}    ✓ Weekly backup created: $BACKUP_SIZE${NC}"
                BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
                chown "$USERNAME:$USER_GROUP" "$WEEKLY_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Weekly archive missing or fails gzip/tar verify; quarantining as .failed" >> "$LOG_FILE"
                echo -e "${RED}    ✗ Weekly archive failed verification; quarantining as .failed${NC}"
                mv -f "$WEEKLY_FILE" "${WEEKLY_FILE}.failed.$(date +%s)" 2>/dev/null || rm -f "$WEEKLY_FILE"
            fi
        else
            echo -e "${YELLOW}    ⊙ Weekly backup already exists${NC}"
        fi
    fi

    # 3. MONTHLY BACKUP (First Saturday only)
    if [ "$IS_FIRST_SATURDAY" = true ]; then
        MONTHLY_FILE="$BACKUP_DIR/${PROJECT_NAME}-monthly-${TODAY}.tar.gz"
        if [ ! -f "$MONTHLY_FILE" ]; then
            echo -e "${GREEN}  → Creating monthly backup...${NC}"
            tar -czf "$MONTHLY_FILE" -C "$USER_HOME/projects" \
                --exclude='data/netdata/cache/*.db*' \
                --exclude='data/volume-backups/*' \
                --exclude='data/mongodb/journal/*' \
                --exclude='data/gitlab/logs/*.log' \
                "$PROJECT_NAME" 2>&1 | tee -a "$LOG_FILE" || true
            if [ -s "$MONTHLY_FILE" ] \
               && gzip -t "$MONTHLY_FILE" 2>/dev/null \
               && tar -tzf "$MONTHLY_FILE" >/dev/null 2>&1; then
                BACKUP_SIZE=$(du -sh "$MONTHLY_FILE" | cut -f1)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - MONTHLY - Created: $(basename "$MONTHLY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
                echo -e "${GREEN}    ✓ Monthly backup created: $BACKUP_SIZE${NC}"
                BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
                chown "$USERNAME:$USER_GROUP" "$MONTHLY_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Monthly archive missing or fails gzip/tar verify; quarantining as .failed" >> "$LOG_FILE"
                echo -e "${RED}    ✗ Monthly archive failed verification; quarantining as .failed${NC}"
                mv -f "$MONTHLY_FILE" "${MONTHLY_FILE}.failed.$(date +%s)" 2>/dev/null || rm -f "$MONTHLY_FILE"
            fi
        else
            echo -e "${YELLOW}    ⊙ Monthly backup already exists${NC}"
        fi
    fi

    # 4. ROTATE OLD BACKUPS
    echo -e "${BLUE}  → Rotating old backups...${NC}"
    BACKUPS_DELETED=0

    # Rotate daily backups (keep last 7)
    DAILY_COUNT=$(ls -1 "$BACKUP_DIR/${PROJECT_NAME}-daily-"*.tar.gz 2>/dev/null | wc -l)
    if [ "$DAILY_COUNT" -gt "$RETENTION_DAILY" ]; then
        DELETE_COUNT=$((DAILY_COUNT - RETENTION_DAILY))
        echo "    Daily: $DAILY_COUNT found, deleting oldest $DELETE_COUNT"
        ls -1t "$BACKUP_DIR/${PROJECT_NAME}-daily-"*.tar.gz | tail -n "$DELETE_COUNT" | while read -r old_file; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETE - Daily: $(basename "$old_file")" >> "$LOG_FILE"
            rm -f "$old_file"
            BACKUPS_DELETED=$((BACKUPS_DELETED + 1))
            echo "      Deleted: $(basename "$old_file")"
        done
    else
        echo "    Daily: $DAILY_COUNT found (keeping all)"
    fi

    # Rotate weekly backups (keep last 4)
    WEEKLY_COUNT=$(ls -1 "$BACKUP_DIR/${PROJECT_NAME}-weekly-"*.tar.gz 2>/dev/null | wc -l)
    if [ "$WEEKLY_COUNT" -gt "$RETENTION_WEEKLY" ]; then
        DELETE_COUNT=$((WEEKLY_COUNT - RETENTION_WEEKLY))
        echo "    Weekly: $WEEKLY_COUNT found, deleting oldest $DELETE_COUNT"
        ls -1t "$BACKUP_DIR/${PROJECT_NAME}-weekly-"*.tar.gz | tail -n "$DELETE_COUNT" | while read -r old_file; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETE - Weekly: $(basename "$old_file")" >> "$LOG_FILE"
            rm -f "$old_file"
            BACKUPS_DELETED=$((BACKUPS_DELETED + 1))
            echo "      Deleted: $(basename "$old_file")"
        done
    else
        echo "    Weekly: $WEEKLY_COUNT found (keeping all)"
    fi

    # Rotate monthly backups (keep last 6)
    MONTHLY_COUNT=$(ls -1 "$BACKUP_DIR/${PROJECT_NAME}-monthly-"*.tar.gz 2>/dev/null | wc -l)
    if [ "$MONTHLY_COUNT" -gt "$RETENTION_MONTHLY" ]; then
        DELETE_COUNT=$((MONTHLY_COUNT - RETENTION_MONTHLY))
        echo "    Monthly: $MONTHLY_COUNT found, deleting oldest $DELETE_COUNT"
        ls -1t "$BACKUP_DIR/${PROJECT_NAME}-monthly-"*.tar.gz | tail -n "$DELETE_COUNT" | while read -r old_file; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETE - Monthly: $(basename "$old_file")" >> "$LOG_FILE"
            rm -f "$old_file"
            BACKUPS_DELETED=$((BACKUPS_DELETED + 1))
            echo "      Deleted: $(basename "$old_file")"
        done
    else
        echo "    Monthly: $MONTHLY_COUNT found (keeping all)"
    fi

    # Summary
    TOTAL_BACKUPS=$(ls -1 "$BACKUP_DIR/${PROJECT_NAME}-"*.tar.gz 2>/dev/null | wc -l)
    BACKUP_DIR_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)

    echo -e "${GREEN}  ✓ Backup complete for $USERNAME${NC}"
    echo "    Backups created: $BACKUPS_CREATED"
    echo "    Backups deleted: $BACKUPS_DELETED"
    echo "    Total backups: $TOTAL_BACKUPS"
    echo "    Backup directory size: $BACKUP_DIR_SIZE"

    # Log summary
    {
        echo "Backups created: $BACKUPS_CREATED"
        echo "Backups deleted: $BACKUPS_DELETED"
        echo "Total backups: $TOTAL_BACKUPS"
        echo "Backup directory size: $BACKUP_DIR_SIZE"
        echo "Status: SUCCESS"
        echo "Backup completed: $(date '+%Y-%m-%d %H:%M:%S')"
    } >> "$LOG_FILE"

    echo ""
done

echo -e "${GREEN}=== All backups completed ===${NC}"
