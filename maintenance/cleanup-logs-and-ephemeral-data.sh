#!/bin/bash
################################################################################
# Log Rotation and Ephemeral Data Cleanup Script
################################################################################
# Purpose: Prevent logs and ephemeral data from growing indefinitely
# Schedule: Run weekly via cron (recommended: Sundays at 3 AM)
# Usage: sudo ./cleanup-logs-and-ephemeral-data.sh [--dry-run]
#
# Cron example:
# 0 3 * * 0 /home/administrator/projects/devscripts/maintenance/cleanup-logs-and-ephemeral-data.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
fi

LOG_DIR="/home/administrator/projects/devscripts/maintenance/logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/cleanup-$(date +%Y-%m-%d-%H%M%S).log"

echo -e "${BLUE}=== Log and Ephemeral Data Cleanup ===${NC}"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Log file: $LOGFILE"
echo ""

# Logging function
log() {
    echo "$1" | tee -a "$LOGFILE"
}

log_color() {
    echo -e "$1"
    echo "$2" >> "$LOGFILE"
}

################################################################################
# 1. DOCKER CONTAINER LOG ROTATION
################################################################################
log_color "${BLUE}--- Docker Container Logs ---${NC}" "--- Docker Container Logs ---"

# Get list of all running containers
CONTAINERS=$(docker ps --format '{{.Names}}')

for CONTAINER in $CONTAINERS; do
    LOG_PATH=$(docker inspect --format='{{.LogPath}}' "$CONTAINER" 2>/dev/null || echo "")

    if [ -z "$LOG_PATH" ]; then
        log_color "${YELLOW}  ⊘ $CONTAINER: No log path found${NC}" "  ⊘ $CONTAINER: No log path found"
        continue
    fi

    if [ ! -f "$LOG_PATH" ]; then
        log_color "${YELLOW}  ⊘ $CONTAINER: Log file doesn't exist${NC}" "  ⊘ $CONTAINER: Log file doesn't exist"
        continue
    fi

    LOG_SIZE=$(du -h "$LOG_PATH" 2>/dev/null | cut -f1)
    LOG_SIZE_BYTES=$(stat -f%z "$LOG_PATH" 2>/dev/null || stat -c%s "$LOG_PATH" 2>/dev/null || echo 0)

    # Only rotate logs larger than 100MB
    if [ "$LOG_SIZE_BYTES" -gt 104857600 ]; then
        log_color "${YELLOW}  → $CONTAINER: $LOG_SIZE (rotating)${NC}" "  → $CONTAINER: $LOG_SIZE (rotating)"

        if [ "$DRY_RUN" = false ]; then
            # Truncate log file (Docker will continue writing to it)
            truncate -s 0 "$LOG_PATH"
            log_color "${GREEN}    ✓ Rotated${NC}" "    ✓ Rotated"
        else
            log_color "${YELLOW}    ⊙ Would rotate${NC}" "    ⊙ Would rotate"
        fi
    else
        log "  ✓ $CONTAINER: $LOG_SIZE (under threshold)"
    fi
done

echo ""

################################################################################
# 2. GITLAB LOGS
################################################################################
log_color "${BLUE}--- GitLab Logs ---${NC}" "--- GitLab Logs ---"

GITLAB_LOG_DIR="/home/administrator/projects/data/gitlab/logs"

if [ -d "$GITLAB_LOG_DIR" ]; then
    # Find logs older than 30 days
    OLD_LOGS=$(find "$GITLAB_LOG_DIR" -name "*.log" -type f -mtime +30 2>/dev/null || echo "")

    if [ -n "$OLD_LOGS" ]; then
        log_color "${YELLOW}  → Found logs older than 30 days${NC}" "  → Found logs older than 30 days"

        while IFS= read -r LOGFILE_PATH; do
            LOG_SIZE=$(du -h "$LOGFILE_PATH" 2>/dev/null | cut -f1)
            RELATIVE_PATH=$(echo "$LOGFILE_PATH" | sed "s|$GITLAB_LOG_DIR/||")

            log "    - $RELATIVE_PATH ($LOG_SIZE)"

            if [ "$DRY_RUN" = false ]; then
                rm -f "$LOGFILE_PATH"
            fi
        done <<< "$OLD_LOGS"

        if [ "$DRY_RUN" = false ]; then
            log_color "${GREEN}  ✓ Deleted old logs${NC}" "  ✓ Deleted old logs"
        else
            log_color "${YELLOW}  ⊙ Would delete old logs${NC}" "  ⊙ Would delete old logs"
        fi
    else
        log "  ✓ No logs older than 30 days"
    fi

    # Truncate large current logs (over 500MB)
    LARGE_LOGS=$(find "$GITLAB_LOG_DIR" -name "*.log" -type f -size +500M 2>/dev/null || echo "")

    if [ -n "$LARGE_LOGS" ]; then
        log_color "${YELLOW}  → Found large logs (>500MB) to truncate${NC}" "  → Found large logs (>500MB) to truncate"

        while IFS= read -r LOGFILE_PATH; do
            LOG_SIZE=$(du -h "$LOGFILE_PATH" 2>/dev/null | cut -f1)
            RELATIVE_PATH=$(echo "$LOGFILE_PATH" | sed "s|$GITLAB_LOG_DIR/||")

            log "    - $RELATIVE_PATH ($LOG_SIZE)"

            if [ "$DRY_RUN" = false ]; then
                # Keep last 10000 lines
                tail -n 10000 "$LOGFILE_PATH" > "$LOGFILE_PATH.tmp"
                mv "$LOGFILE_PATH.tmp" "$LOGFILE_PATH"
            fi
        done <<< "$LARGE_LOGS"

        if [ "$DRY_RUN" = false ]; then
            log_color "${GREEN}  ✓ Truncated large logs (kept last 10000 lines)${NC}" "  ✓ Truncated large logs (kept last 10000 lines)"
        else
            log_color "${YELLOW}  ⊙ Would truncate large logs${NC}" "  ⊙ Would truncate large logs"
        fi
    else
        log "  ✓ No large logs to truncate"
    fi
else
    log_color "${YELLOW}  ⊘ GitLab log directory not found${NC}" "  ⊘ GitLab log directory not found"
fi

echo ""

################################################################################
# 3. NETDATA CACHE CLEANUP
################################################################################
log_color "${BLUE}--- Netdata Cache ---${NC}" "--- Netdata Cache ---"

NETDATA_CACHE="/home/administrator/projects/data/netdata/cache"

if [ -d "$NETDATA_CACHE" ]; then
    CACHE_SIZE=$(du -sh "$NETDATA_CACHE" 2>/dev/null | cut -f1)
    log "  Current size: $CACHE_SIZE"

    # Clean up old metadata (these regenerate automatically)
    if [ "$DRY_RUN" = false ]; then
        # Stop netdata container
        log_color "${YELLOW}  → Stopping netdata container...${NC}" "  → Stopping netdata container..."
        docker stop netdata 2>/dev/null || true

        # Remove metadata databases (they'll regenerate)
        rm -f "$NETDATA_CACHE/netdata-meta.db"*
        rm -f "$NETDATA_CACHE/ml.db"*
        rm -f "$NETDATA_CACHE/context-meta.db"*

        # Restart netdata
        log_color "${YELLOW}  → Starting netdata container...${NC}" "  → Starting netdata container..."
        docker start netdata 2>/dev/null || true

        NEW_SIZE=$(du -sh "$NETDATA_CACHE" 2>/dev/null | cut -f1)
        log_color "${GREEN}  ✓ Cleaned metadata cache: $CACHE_SIZE → $NEW_SIZE${NC}" "  ✓ Cleaned metadata cache: $CACHE_SIZE → $NEW_SIZE"
    else
        log_color "${YELLOW}  ⊙ Would clean metadata cache (requires netdata restart)${NC}" "  ⊙ Would clean metadata cache (requires netdata restart)"
    fi
else
    log_color "${YELLOW}  ⊘ Netdata cache directory not found${NC}" "  ⊘ Netdata cache directory not found"
fi

echo ""

################################################################################
# 4. MONGODB JOURNAL CLEANUP
################################################################################
log_color "${BLUE}--- MongoDB Journal ---${NC}" "--- MongoDB Journal ---"

MONGODB_JOURNAL="/home/administrator/projects/data/mongodb/journal"

if [ -d "$MONGODB_JOURNAL" ]; then
    JOURNAL_SIZE=$(du -sh "$MONGODB_JOURNAL" 2>/dev/null | cut -f1)
    log "  Current size: $JOURNAL_SIZE"

    # MongoDB journals are safe to delete if we force a checkpoint
    if [ "$DRY_RUN" = false ]; then
        # Force MongoDB to checkpoint (writes everything to data files)
        log_color "${YELLOW}  → Running MongoDB checkpoint...${NC}" "  → Running MongoDB checkpoint..."
        docker exec mongodb mongosh --eval "db.adminCommand({fsync: 1, async: false})" 2>/dev/null || true

        # Old journal files can now be removed (MongoDB will recreate as needed)
        find "$MONGODB_JOURNAL" -name "WiredTigerLog.*" -mtime +7 -delete 2>/dev/null || true

        NEW_SIZE=$(du -sh "$MONGODB_JOURNAL" 2>/dev/null | cut -f1)
        log_color "${GREEN}  ✓ Cleaned old journals: $JOURNAL_SIZE → $NEW_SIZE${NC}" "  ✓ Cleaned old journals: $JOURNAL_SIZE → $NEW_SIZE"
    else
        log_color "${YELLOW}  ⊙ Would clean old journal files (>7 days)${NC}" "  ⊙ Would clean old journal files (>7 days)"
    fi
else
    log_color "${YELLOW}  ⊘ MongoDB journal directory not found${NC}" "  ⊘ MongoDB journal directory not found"
fi

echo ""

################################################################################
# 5. QDRANT WAL CLEANUP
################################################################################
log_color "${BLUE}--- Qdrant WAL ---${NC}" "--- Qdrant WAL ---"

QDRANT_DATA="/home/administrator/projects/data/qdrant/collections"

if [ -d "$QDRANT_DATA" ]; then
    WAL_SIZE=$(du -sh "$QDRANT_DATA"/*/0/wal 2>/dev/null | awk '{sum+=$1} END {print sum "M"}' || echo "0M")
    log "  Current WAL size: $WAL_SIZE"

    # Qdrant manages its own WAL, but we can force a snapshot
    if [ "$DRY_RUN" = false ]; then
        log_color "${YELLOW}  → Creating Qdrant snapshot (flushes WAL)...${NC}" "  → Creating Qdrant snapshot (flushes WAL)..."
        # Qdrant will flush WAL during snapshot
        docker exec qdrant curl -X POST "http://localhost:6333/collections/openmemory/snapshots" 2>/dev/null || true
        docker exec qdrant curl -X POST "http://localhost:6333/collections/mem0migrations/snapshots" 2>/dev/null || true

        log_color "${GREEN}  ✓ Qdrant snapshots created${NC}" "  ✓ Qdrant snapshots created"
    else
        log_color "${YELLOW}  ⊙ Would create Qdrant snapshots${NC}" "  ⊙ Would create Qdrant snapshots"
    fi
else
    log_color "${YELLOW}  ⊘ Qdrant data directory not found${NC}" "  ⊘ Qdrant data directory not found"
fi

echo ""

################################################################################
# 6. OLD VOLUME BACKUPS CLEANUP
################################################################################
log_color "${BLUE}--- Old Volume Backups ---${NC}" "--- Old Volume Backups ---"

VOLUME_BACKUPS="/home/administrator/projects/data/volume-backups"

if [ -d "$VOLUME_BACKUPS" ]; then
    BACKUP_SIZE=$(du -sh "$VOLUME_BACKUPS" 2>/dev/null | cut -f1)
    BACKUP_COUNT=$(ls -1 "$VOLUME_BACKUPS" 2>/dev/null | wc -l)

    log "  Found: $BACKUP_COUNT files ($BACKUP_SIZE)"
    log_color "${YELLOW}  → These are old one-time database backups (redundant)${NC}" "  → These are old one-time database backups (redundant)"

    if [ "$DRY_RUN" = false ]; then
        rm -rf "$VOLUME_BACKUPS"
        log_color "${GREEN}  ✓ Removed volume-backups directory${NC}" "  ✓ Removed volume-backups directory"
    else
        log_color "${YELLOW}  ⊙ Would remove volume-backups directory${NC}" "  ⊙ Would remove volume-backups directory"
    fi
else
    log "  ✓ No volume-backups directory found"
fi

echo ""

################################################################################
# SUMMARY
################################################################################
log_color "${GREEN}=== Cleanup Complete ===${NC}" "=== Cleanup Complete ==="
log "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
log "Log saved: $LOGFILE"

if [ "$DRY_RUN" = true ]; then
    echo ""
    log_color "${YELLOW}This was a dry run. Run without --dry-run to apply changes.${NC}" "This was a dry run. Run without --dry-run to apply changes."
fi
