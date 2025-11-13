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

set -e

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
PROJECT_NAME="data"
RETENTION_DAILY=7
RETENTION_WEEKLY=4
RETENTION_MONTHLY=6

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
        # Set ownership - use the user's primary group
        USER_GROUP=$(id -gn "$USERNAME")
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

    # 1. DAILY BACKUP (always)
    DAILY_FILE="$BACKUP_DIR/${PROJECT_NAME}-daily-${TODAY}.tar.gz"
    if [ ! -f "$DAILY_FILE" ]; then
        echo -e "${GREEN}  → Creating daily backup...${NC}"
        if tar -czf "$DAILY_FILE" -C "$USER_HOME/projects" "$PROJECT_NAME" 2>&1 | tee -a "$LOG_FILE"; then
            BACKUP_SIZE=$(du -sh "$DAILY_FILE" | cut -f1)
            echo "$(date '+%Y-%m-%d %H:%M:%S') - DAILY - Created: $(basename "$DAILY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
            echo -e "${GREEN}    ✓ Daily backup created: $BACKUP_SIZE${NC}"
            BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
            chown "$USERNAME:$USER_GROUP" "$DAILY_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Daily backup failed" >> "$LOG_FILE"
            echo -e "${RED}    ✗ Daily backup failed${NC}"
        fi
    else
        echo -e "${YELLOW}    ⊙ Daily backup already exists${NC}"
    fi

    # 2. WEEKLY BACKUP (Saturdays only)
    if [ "$IS_SATURDAY" = true ]; then
        WEEKLY_FILE="$BACKUP_DIR/${PROJECT_NAME}-weekly-${TODAY}.tar.gz"
        if [ ! -f "$WEEKLY_FILE" ]; then
            echo -e "${GREEN}  → Creating weekly backup...${NC}"
            if tar -czf "$WEEKLY_FILE" -C "$USER_HOME/projects" "$PROJECT_NAME" 2>&1 | tee -a "$LOG_FILE"; then
                BACKUP_SIZE=$(du -sh "$WEEKLY_FILE" | cut -f1)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - WEEKLY - Created: $(basename "$WEEKLY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
                echo -e "${GREEN}    ✓ Weekly backup created: $BACKUP_SIZE${NC}"
                BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
                chown "$USERNAME:$USER_GROUP" "$WEEKLY_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Weekly backup failed" >> "$LOG_FILE"
                echo -e "${RED}    ✗ Weekly backup failed${NC}"
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
            if tar -czf "$MONTHLY_FILE" -C "$USER_HOME/projects" "$PROJECT_NAME" 2>&1 | tee -a "$LOG_FILE"; then
                BACKUP_SIZE=$(du -sh "$MONTHLY_FILE" | cut -f1)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - MONTHLY - Created: $(basename "$MONTHLY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
                echo -e "${GREEN}    ✓ Monthly backup created: $BACKUP_SIZE${NC}"
                BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
                chown "$USERNAME:$USER_GROUP" "$MONTHLY_FILE"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR - Monthly backup failed" >> "$LOG_FILE"
                echo -e "${RED}    ✗ Monthly backup failed${NC}"
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
