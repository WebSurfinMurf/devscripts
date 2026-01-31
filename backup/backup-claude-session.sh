#!/bin/bash
################################################################################
# Claude Code Session Data Backup
################################################################################
# Backs up Claude Code session data that is NOT tracked in git:
# - projects/     - Session/project data
# - file-history/ - File edit history
# - todos/        - Todo lists
# - history.jsonl - Command history
#
# Does NOT backup (tracked in git or ephemeral):
# - skills/       - Now tracked in claude-skills/* repos
# - agents/       - Now tracked in claude-skills/* repos
# - commands/     - Now tracked in claude-skills/* repos
# - hooks/        - Now tracked in claude-skills/* repos
# - docs/         - Now tracked in claude-skills/* repos
# - tools/        - Now tracked in claude-skills/* repos
# - debug/        - Ephemeral debug logs
# - cache/        - Ephemeral cache
# - logs/         - Ephemeral logs
# - plugins/      - Installed, not config
# - shell-snapshots/ - Ephemeral
# - statsig/      - Ephemeral
#
# Location: /home/administrator/projects/devscripts/backup/backup-claude-session.sh
# Usage: ./backup-claude-session.sh
################################################################################

set -e

# Source environment variables if not set
if [ -z "$BACKUPROOT" ]; then
    if [ -f /etc/profile.d/backups.sh ]; then
        source /etc/profile.d/backups.sh
    else
        echo "ERROR: BACKUPROOT not set and /etc/profile.d/backups.sh not found"
        exit 1
    fi
fi

# Configuration
BACKUP_NAME="claude-session"
RETENTION_DAILY=7
RETENTION_WEEKLY=4

# Date calculations
TODAY=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)  # 1=Monday, 6=Saturday, 7=Sunday

IS_SATURDAY=false
if [ "$DAY_OF_WEEK" -eq 6 ]; then
    IS_SATURDAY=true
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Users to process
USERS=("administrator" "websurfinmurf")

echo -e "${BLUE}=== Claude Code Session Backup ===${NC}"
echo "Date: $TODAY"
echo ""

for USERNAME in "${USERS[@]}"; do
    echo -e "${BLUE}--- Processing user: $USERNAME ---${NC}"

    USER_HOME="/home/$USERNAME"
    CLAUDE_DIR="$USER_HOME/.claude"
    BACKUP_DIR="$BACKUPROOT/$USERNAME/claude"
    LOG_FILE="$BACKUP_DIR/backup.log"

    # Check if .claude directory exists
    if [ ! -d "$CLAUDE_DIR" ]; then
        echo -e "${YELLOW}  ⊘ Skipping: $CLAUDE_DIR does not exist${NC}"
        continue
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    USER_GROUP=$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")
    chown -R "$USERNAME:$USER_GROUP" "$BACKUP_DIR" 2>/dev/null || true

    # Calculate source sizes
    echo "  Source: $CLAUDE_DIR"
    echo "  Backing up session data only (skills tracked in git)"

    # Items to backup (session data only)
    BACKUP_ITEMS=""
    [ -d "$CLAUDE_DIR/projects" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/projects"
    [ -d "$CLAUDE_DIR/file-history" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/file-history"
    [ -d "$CLAUDE_DIR/todos" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/todos"
    [ -f "$CLAUDE_DIR/history.jsonl" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/history.jsonl"
    [ -d "$CLAUDE_DIR/plans" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/plans"
    [ -d "$CLAUDE_DIR/paste-cache" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/paste-cache"
    [ -d "$CLAUDE_DIR/session-env" ] && BACKUP_ITEMS="$BACKUP_ITEMS .claude/session-env"

    if [ -z "$BACKUP_ITEMS" ]; then
        echo -e "${YELLOW}  ⊘ No session data to backup${NC}"
        continue
    fi

    # Also backup ~/projects/.claude session data
    PROJECTS_CLAUDE="$USER_HOME/projects/.claude"
    if [ -d "$PROJECTS_CLAUDE/projects" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS projects/.claude/projects"
    fi
    if [ -d "$PROJECTS_CLAUDE/todos" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS projects/.claude/todos"
    fi
    if [ -d "$PROJECTS_CLAUDE/shell-snapshots" ]; then
        BACKUP_ITEMS="$BACKUP_ITEMS projects/.claude/shell-snapshots"
    fi

    # Log start
    {
        echo ""
        echo "========================================"
        echo "Backup started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Items: $BACKUP_ITEMS"
        echo "========================================"
    } >> "$LOG_FILE"

    # 1. DAILY BACKUP
    DAILY_FILE="$BACKUP_DIR/${BACKUP_NAME}-daily-${TODAY}.tar.gz"
    if [ ! -f "$DAILY_FILE" ]; then
        echo -e "${GREEN}  → Creating daily backup...${NC}"
        if tar -czf "$DAILY_FILE" -C "$USER_HOME" $BACKUP_ITEMS 2>&1 | tee -a "$LOG_FILE"; then
            BACKUP_SIZE=$(du -sh "$DAILY_FILE" | cut -f1)
            echo "$(date '+%Y-%m-%d %H:%M:%S') - DAILY - Created: $(basename "$DAILY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
            echo -e "${GREEN}    ✓ Daily backup created: $BACKUP_SIZE${NC}"
            chown "$USERNAME:$USER_GROUP" "$DAILY_FILE" 2>/dev/null || true
        else
            echo -e "${RED}    ✗ Daily backup failed${NC}"
        fi
    else
        echo -e "${YELLOW}    ⊙ Daily backup already exists${NC}"
    fi

    # 2. WEEKLY BACKUP (Saturdays)
    if [ "$IS_SATURDAY" = true ]; then
        WEEKLY_FILE="$BACKUP_DIR/${BACKUP_NAME}-weekly-${TODAY}.tar.gz"
        if [ ! -f "$WEEKLY_FILE" ]; then
            echo -e "${GREEN}  → Creating weekly backup...${NC}"
            if tar -czf "$WEEKLY_FILE" -C "$USER_HOME" $BACKUP_ITEMS 2>&1 | tee -a "$LOG_FILE"; then
                BACKUP_SIZE=$(du -sh "$WEEKLY_FILE" | cut -f1)
                echo "$(date '+%Y-%m-%d %H:%M:%S') - WEEKLY - Created: $(basename "$WEEKLY_FILE") ($BACKUP_SIZE)" >> "$LOG_FILE"
                echo -e "${GREEN}    ✓ Weekly backup created: $BACKUP_SIZE${NC}"
                chown "$USERNAME:$USER_GROUP" "$WEEKLY_FILE" 2>/dev/null || true
            fi
        fi
    fi

    # 3. ROTATE OLD BACKUPS
    echo -e "${BLUE}  → Rotating old backups...${NC}"

    # Rotate daily (keep 7)
    DAILY_COUNT=$(ls -1 "$BACKUP_DIR/${BACKUP_NAME}-daily-"*.tar.gz 2>/dev/null | wc -l)
    if [ "$DAILY_COUNT" -gt "$RETENTION_DAILY" ]; then
        DELETE_COUNT=$((DAILY_COUNT - RETENTION_DAILY))
        ls -1t "$BACKUP_DIR/${BACKUP_NAME}-daily-"*.tar.gz | tail -n "$DELETE_COUNT" | while read -r old_file; do
            rm -f "$old_file"
            echo "      Deleted: $(basename "$old_file")"
        done
    fi

    # Rotate weekly (keep 4)
    WEEKLY_COUNT=$(ls -1 "$BACKUP_DIR/${BACKUP_NAME}-weekly-"*.tar.gz 2>/dev/null | wc -l)
    if [ "$WEEKLY_COUNT" -gt "$RETENTION_WEEKLY" ]; then
        DELETE_COUNT=$((WEEKLY_COUNT - RETENTION_WEEKLY))
        ls -1t "$BACKUP_DIR/${BACKUP_NAME}-weekly-"*.tar.gz | tail -n "$DELETE_COUNT" | while read -r old_file; do
            rm -f "$old_file"
            echo "      Deleted: $(basename "$old_file")"
        done
    fi

    BACKUP_DIR_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo -e "${GREEN}  ✓ Backup complete for $USERNAME ($BACKUP_DIR_SIZE)${NC}"
    echo ""
done

echo -e "${GREEN}=== Claude session backup completed ===${NC}"
