#!/bin/bash
#
# cleanserver.sh - Server Cleanup Script
# Cleans up Docker resources, Qdrant snapshots, stale files, and logs.
#
# Loki retention is handled natively via loki.yaml (retention_period),
# NOT by this script. Do not add filesystem-level Loki cleanup here.
#
# Exit codes:
#   0 = Success, no errors
#   N = Number of errors encountered
#
# Usage: ./cleanserver.sh [--dry-run]
#

# Best-effort mode: don't abort on errors, track them instead
set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

ERROR_COUNT=0

step_ok()   { echo -e "  ${GREEN}✓ $1${NC}"; }
step_fail() { echo -e "  ${RED}✗ $1${NC}"; ((ERROR_COUNT++)) || true; }
step_skip() { echo -e "  ${YELLOW}⚠ $1${NC}"; }
step_dry()  { echo -e "  ${YELLOW}[dry-run] would: $1${NC}"; }

echo "========================================"
echo "Server Cleanup Script"
echo "========================================"
echo "Started: $(date)"
$DRY_RUN && echo -e "${YELLOW}DRY RUN — no changes will be made${NC}"
echo ""

#
# 1. CHECKS
#
if [ "$(whoami)" != "administrator" ]; then
    echo -e "${RED}ERROR: Must run as administrator${NC}"
    exit 1
fi
if ! systemctl is-active --quiet docker; then
    echo -e "${RED}ERROR: Docker daemon is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Running as administrator, Docker is up"
echo ""

#
# 2. INITIAL STATE
#
echo "========================================="
echo "Disk Usage Before Cleanup"
echo "========================================="
docker system df
df -h / | tail -1 | awk '{print "Filesystem: " $2 " used, " $4 " avail (" $5 ")"}'
echo ""

#
# 3. DOCKER BUILD CACHE
# Safe: only affects layer cache, rebuilds take longer next time
#
echo -e "${BLUE}[1/7] Docker build cache${NC}"
CACHE_SIZE=$(docker system df --format '{{.Size}}' 2>/dev/null | tail -1)
echo "  Current: $CACHE_SIZE"
if [ "$DRY_RUN" = true ]; then
    step_dry "docker builder prune -a -f"
elif docker builder prune -a -f > /dev/null 2>&1; then
    step_ok "Build cache cleared"
else
    step_fail "Build cache prune failed"
fi
echo ""

#
# 4. DANGLING DOCKER IMAGES (untagged layers only)
# Safe: only removes images with <none> tag — never removes tagged images
# that could be needed for rollback or pre-pulled deployments.
#
echo -e "${BLUE}[2/7] Dangling Docker images${NC}"
DANGLING=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
echo "  Dangling images: $DANGLING"
if [ "$DRY_RUN" = true ]; then
    step_dry "docker image prune -f"
elif docker image prune -f > /dev/null 2>&1; then
    step_ok "Dangling images removed"
else
    step_fail "Image prune failed"
fi
echo ""

#
# 5. STOPPED CONTAINERS (no volume prune — too risky for automated runs)
# Safe: only removes exited containers. Volumes are left untouched to
# prevent data loss from temporarily stopped services.
#
echo -e "${BLUE}[3/7] Stopped containers${NC}"
STOPPED=$(docker ps -a --filter "status=exited" -q 2>/dev/null | wc -l)
echo "  Stopped containers: $STOPPED"
if [ "$DRY_RUN" = true ]; then
    step_dry "docker container prune -f"
elif docker container prune -f > /dev/null 2>&1; then
    step_ok "Stopped containers removed"
else
    step_fail "Container prune failed"
fi
echo ""

#
# 6. QDRANT CONTAINER SNAPSHOTS
# These accumulate in the container's writable layer (not the volume mount).
# Qdrant's API doesn't manage these — they were created by external cron jobs.
# Safe to delete old .snapshot files directly; Qdrant doesn't use them at runtime.
#
echo -e "${BLUE}[4/7] Qdrant container snapshots${NC}"
QDRANT_SNAP_SIZE=$(docker exec qdrant du -sh /qdrant/snapshots 2>/dev/null | cut -f1 || echo "0")
echo "  Snapshots in container: $QDRANT_SNAP_SIZE"

if docker exec qdrant ls /qdrant/snapshots/ >/dev/null 2>&1; then
    COLLECTIONS=$(docker exec qdrant ls /qdrant/snapshots/ 2>/dev/null | grep -v '^tmp$' || true)

    for COLLECTION in $COLLECTIONS; do
        # Count .snapshot files (not checksums)
        SNAP_COUNT=$(docker exec qdrant find "/qdrant/snapshots/${COLLECTION}" -name "*.snapshot" -type f 2>/dev/null | wc -l)

        if [ "$SNAP_COUNT" -le 2 ]; then
            echo "  $COLLECTION: $SNAP_COUNT snapshots (keeping all)"
            continue
        fi

        DELETE_COUNT=$((SNAP_COUNT - 2))
        echo "  $COLLECTION: $SNAP_COUNT snapshots, deleting $DELETE_COUNT oldest"

        if [ "$DRY_RUN" = true ]; then
            step_dry "delete $DELETE_COUNT old snapshots from $COLLECTION"
        else
            # Delete all but the 2 newest .snapshot files and their checksums
            docker exec qdrant bash -c "
                ls -1t /qdrant/snapshots/${COLLECTION}/*.snapshot 2>/dev/null | tail -n +3 | while read -r f; do
                    rm -f \"\$f\" \"\${f}.checksum\" 2>/dev/null
                done
            " 2>/dev/null || step_fail "Qdrant snapshot cleanup for $COLLECTION"
        fi
    done

    if [ "$DRY_RUN" = false ]; then
        NEW_SIZE=$(docker exec qdrant du -sh /qdrant/snapshots 2>/dev/null | cut -f1 || echo "?")
        step_ok "Cleaned: $QDRANT_SNAP_SIZE -> $NEW_SIZE"
    fi
else
    step_skip "Qdrant container not running"
fi
echo ""

#
# 7. LOKI LOG RETENTION
# Handled by Loki's native compactor (retention_period in loki.yaml).
# Do NOT delete chunks via filesystem — it breaks Loki's index.
#
echo -e "${BLUE}[5/7] Loki log retention${NC}"
LOKI_CHUNKS="/home/administrator/projects/data/loki/chunks"
if [ -d "$LOKI_CHUNKS" ]; then
    LOKI_SIZE=$(du -sh "$LOKI_CHUNKS" 2>/dev/null | cut -f1)
    echo "  Current chunks: $LOKI_SIZE"
    echo "  Retention managed by Loki compactor (see loki.yaml)"
    step_ok "Checked (no filesystem cleanup — use Loki retention config)"
else
    step_skip "Loki chunks directory not found"
fi
echo ""

#
# 8. OLD LOG FILES (90+ days)
# Uses find -exec for filename safety (no xargs/eval).
#
echo -e "${BLUE}[6/7] Old log files (90+ days)${NC}"
LOGS_DIR="/home/administrator/projects/data/logs"
if [ -d "$LOGS_DIR" ]; then
    OLD_LOG_COUNT=$(find "$LOGS_DIR" -name "*.log" -type f -mtime +90 2>/dev/null | wc -l)
    if [ "$OLD_LOG_COUNT" -gt 0 ]; then
        echo "  Found $OLD_LOG_COUNT file(s)"
        if [ "$DRY_RUN" = true ]; then
            step_dry "delete $OLD_LOG_COUNT log files older than 90 days"
        elif find "$LOGS_DIR" -name "*.log" -type f -mtime +90 -exec rm -f {} + 2>/dev/null; then
            step_ok "Removed $OLD_LOG_COUNT old log files"
        else
            step_fail "Failed to remove some log files"
        fi
    else
        step_ok "None found"
    fi
else
    step_skip "$LOGS_DIR not found"
fi
echo ""

#
# 9. STALE HOME DIRECTORY ARTIFACTS
# Finds old backup/temp dirs matching known patterns, older than 30 days.
#
echo -e "${BLUE}[7/7] Stale home directory artifacts${NC}"
FOUND_STALE=0
while IFS= read -r -d '' d; do
    SIZE=$(du -sh "$d" 2>/dev/null | cut -f1)
    echo "  $d ($SIZE)"
    FOUND_STALE=1
    if [ "$DRY_RUN" = true ]; then
        step_dry "rm -rf $d"
    else
        rm -rf "$d" || step_fail "Failed to remove $d"
    fi
done < <(find /home/administrator -maxdepth 1 -type d \( -name ".claude.backup-*" -o -name "BAKofCLAUDE" -o -name "BAK-claude-*" \) -mtime +30 -print0 2>/dev/null)
if [ "$FOUND_STALE" -eq 0 ]; then
    step_ok "None found"
else
    step_ok "Cleaned"
fi
echo ""

#
# USB BACKUP ROTATION (optional — only if USB mounted)
#
USB_SCRIPT="/home/administrator/projects/data/copy-backups-to-usb.sh"
if [ -f "$USB_SCRIPT" ] && mountpoint -q /mnt/backup 2>/dev/null; then
    echo -e "${BLUE}[bonus] USB backup rotation${NC}"
    USB_BEFORE=$(df -h /mnt/backup | tail -1 | awk '{print $5}')
    echo "  USB drive: $USB_BEFORE full"
    if [ "$DRY_RUN" = true ]; then
        step_dry "run copy-backups-to-usb.sh"
    elif bash "$USB_SCRIPT" 2>/dev/null; then
        USB_AFTER=$(df -h /mnt/backup | tail -1 | awk '{print $5}')
        step_ok "USB: $USB_BEFORE -> $USB_AFTER"
    else
        step_skip "USB copy script had issues"
    fi
    echo ""
fi

#
# FINAL STATE
#
echo "========================================="
echo "Disk Usage After Cleanup"
echo "========================================="
docker system df
df -h / | tail -1 | awk '{print "Filesystem: " $2 " used, " $4 " avail (" $5 ")"}'
echo ""

echo "========================================="
echo "Cleanup Summary"
echo "========================================="
echo "Completed: $(date)"
echo "Errors: $ERROR_COUNT"
$DRY_RUN && echo -e "${YELLOW}This was a dry run.${NC}"

if [ $ERROR_COUNT -eq 0 ]; then
    step_ok "Cleanup completed successfully"
    exit 0
else
    echo -e "${YELLOW}⚠ Cleanup completed with $ERROR_COUNT error(s)${NC}"
    exit $ERROR_COUNT
fi
