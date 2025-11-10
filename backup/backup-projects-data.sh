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
# 3. Users run it from here: ~/projects/devscripts/backup/backup-projects-data.sh
#
# Usage: /home/administrator/projects/devscripts/backup/backup-projects-data.sh [project-name] [--dry-run]
################################################################################

# Backup user project data to external thumb drive
# Multi-user structure: /mnt/backup/backups/usr/{username}/projects/{projectname}/
#
# Usage: ./backup-projects-data.sh [project-name] [--dry-run]
#
# Examples:
#   ./backup-projects-data.sh data              # Backup projects/data
#   ./backup-projects-data.sh data --dry-run    # Test without changes
#   ./backup-projects-data.sh nginx             # Backup projects/nginx

set -e

# Configuration
CURRENT_USER=$(whoami)
SOURCE_BASE="/home/$CURRENT_USER/projects"
BACKUP_MOUNT="/mnt/backup"

# Use $BACKUPS environment variable if set, otherwise construct path
if [ -n "$BACKUPS" ]; then
    BACKUP_BASE="$BACKUPS"
else
    BACKUP_BASE="$BACKUP_MOUNT/backups/usr/$CURRENT_USER/projects"
fi

LOG_DIR="/home/$CURRENT_USER/projects/devscripts/backup/logs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
PROJECT_NAME=""
DRY_RUN=false

for arg in "$@"; do
    if [ "$arg" = "--dry-run" ]; then
        DRY_RUN=true
    else
        PROJECT_NAME="$arg"
    fi
done

# Default to 'data' if no project specified
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="data"
fi

SOURCE_DIR="$SOURCE_BASE/$PROJECT_NAME"
BACKUP_DIR="$BACKUP_BASE/$PROJECT_NAME"
LOG_FILE="$LOG_DIR/backup-$PROJECT_NAME-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log "=== Project Backup ==="
log "User: $CURRENT_USER"
log "Project: $PROJECT_NAME"
log "Started: $(date)"
log "Source: $SOURCE_DIR"
log "Destination: $BACKUP_DIR"
log ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log "${RED}ERROR: Source directory not found: $SOURCE_DIR${NC}"
    log ""
    log "Available projects in $SOURCE_BASE:"
    ls -1 "$SOURCE_BASE" 2>/dev/null || echo "  (none)"
    exit 1
fi

# Check if backup drive is mounted
if ! mount | grep -q "$BACKUP_MOUNT"; then
    log "${RED}ERROR: Backup drive not mounted at $BACKUP_MOUNT${NC}"
    log ""
    log "The backup drive should auto-mount on boot."
    log "If not mounted, check:"
    log "  1. Is the USB drive connected? (lsblk | grep sda)"
    log "  2. Is fstab configured? (grep /dev/sda4 /etc/fstab)"
    log "  3. Try manual mount: sudo mount -a"
    exit 1
fi

# Check if user's backup directory exists (should be created by setup script)
if [ ! -d "$BACKUP_BASE" ]; then
    log "${RED}ERROR: User backup directory not found: $BACKUP_BASE${NC}"
    log ""
    log "Run the setup script first: sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh"
    exit 1
fi

# Check if user has write access to their backup directory
if [ ! -w "$BACKUP_BASE" ]; then
    log "${RED}ERROR: No write permission to $BACKUP_BASE${NC}"
    log ""
    log "Check ownership: ls -ld $BACKUP_BASE"
    exit 1
fi

# Check available space on backup drive
BACKUP_SPACE=$(df -BG "$BACKUP_MOUNT" | tail -1 | awk '{print $4}' | sed 's/G//')
SOURCE_SIZE=$(du -s -BG "$SOURCE_DIR" 2>/dev/null | awk '{print $1}' | sed 's/G//')
log "Backup drive available space: ${BACKUP_SPACE}GB"
log "Source directory size: ${SOURCE_SIZE}GB"

if [ "$BACKUP_SPACE" -lt "$SOURCE_SIZE" ]; then
    log "${YELLOW}WARNING: Low disk space on backup drive${NC}"
fi

# Create project backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Prepare rsync options
RSYNC_OPTS=(
    -avh                    # Archive mode, verbose, human-readable
    --delete                # Delete files in dest that don't exist in source
    --delete-excluded       # Delete excluded files from dest
    --exclude='.tmp'        # Exclude temporary files
    --exclude='*.tmp'
    --exclude='*.log'       # Exclude log files
    --exclude='lost+found'  # Exclude lost+found
    --progress              # Show progress
    --stats                 # Show statistics
)

# Check for dry-run flag
if [ "$DRY_RUN" = true ]; then
    log "${YELLOW}DRY RUN MODE - No files will be modified${NC}"
    RSYNC_OPTS+=(--dry-run)
fi

# Perform backup
log ""
log "${GREEN}Starting rsync backup...${NC}"
log ""

if rsync "${RSYNC_OPTS[@]}" "$SOURCE_DIR/" "$BACKUP_DIR/" 2>&1 | tee -a "$LOG_FILE"; then
    log ""
    log "${GREEN}✓ Backup completed successfully${NC}"
    log "Completed: $(date)"

    # Create timestamp file
    if [ "$DRY_RUN" = false ]; then
        echo "Last backup: $(date)" > "$BACKUP_DIR/.last-backup"
        echo "User: $CURRENT_USER" >> "$BACKUP_DIR/.last-backup"
        echo "Project: $PROJECT_NAME" >> "$BACKUP_DIR/.last-backup"
    fi

    # Show backup summary
    log ""
    log "=== Backup Summary ==="
    log "Backup location: $BACKUP_DIR"
    if [ -f "$BACKUP_DIR/.last-backup" ]; then
        log "Last backup info:"
        cat "$BACKUP_DIR/.last-backup" | tee -a "$LOG_FILE"
    fi

    # Disk usage
    log ""
    log "Disk usage on backup drive:"
    df -h "$BACKUP_MOUNT" | tail -1 | tee -a "$LOG_FILE"

    log ""
    log "User's backup directory size:"
    du -sh "$BACKUP_BASE" 2>/dev/null | tee -a "$LOG_FILE"

    exit 0
else
    log ""
    log "${RED}✗ Backup failed${NC}"
    log "Check log file: $LOG_FILE"
    exit 1
fi
