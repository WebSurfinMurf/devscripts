#!/bin/bash
#
# cleanserver.sh - Server Cleanup Script (Conservative)
# Cleans up Docker resources and system cache safely
#
# Exit codes:
#   0 = Success, no errors
#   N = Number of errors encountered
#
# Usage: ./cleanserver.sh
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error counter
ERROR_COUNT=0

# Space tracking
SPACE_BEFORE=0
SPACE_AFTER=0

echo "========================================"
echo "Server Cleanup Script"
echo "========================================"
echo "Started: $(date)"
echo ""

#
# 1. USER CHECK - Must run as administrator
#
if [ "$(whoami)" != "administrator" ]; then
    echo -e "${RED}ERROR: This script must be run as the 'administrator' user${NC}"
    echo "Current user: $(whoami)"
    echo "Please run: su - administrator -c '/home/administrator/projects/devscripts/cleanserver.sh'"
    exit 1
fi
echo -e "${GREEN}✓${NC} Running as administrator"
echo ""

#
# 2. DOCKER DAEMON CHECK
#
if ! systemctl is-active --quiet docker; then
    echo -e "${RED}ERROR: Docker daemon is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Docker daemon is running"
echo ""

#
# 3. CAPTURE INITIAL DISK USAGE
#
echo "========================================="
echo "Disk Usage Before Cleanup"
echo "========================================="
docker system df
echo ""

SPACE_BEFORE=$(docker system df --format "{{.Reclaimable}}" | grep -oP '\d+(\.\d+)?' | head -1 | cut -d. -f1)
echo ""

#
# 4. CLEANUP OPERATIONS
#
echo "========================================="
echo "Starting Cleanup Operations"
echo "========================================="
echo ""

# 4.1 Remove stopped containers
echo "[1/5] Pruning stopped containers..."
if docker container prune -f > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Stopped containers removed"
else
    echo -e "${RED}✗${NC} Failed to prune containers"
    ((ERROR_COUNT++))
fi
echo ""

# 4.2 Remove dangling images
echo "[2/5] Pruning dangling images..."
if docker image prune -f > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Dangling images removed"
else
    echo -e "${RED}✗${NC} Failed to prune images"
    ((ERROR_COUNT++))
fi
echo ""

# 4.3 Remove dangling volumes (SAFE - only removes unused volumes)
echo "[3/5] Pruning dangling volumes..."
if docker volume prune -f > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Dangling volumes removed"
else
    echo -e "${RED}✗${NC} Failed to prune volumes"
    ((ERROR_COUNT++))
fi
echo ""

# 4.4 Remove build cache
echo "[4/5] Pruning build cache..."
if docker builder prune -f > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Build cache removed"
else
    echo -e "${RED}✗${NC} Failed to prune build cache"
    ((ERROR_COUNT++))
fi
echo ""

# 4.5 Remove old log files (90+ days)
echo "[5/5] Removing old log files (90+ days)..."
LOGS_DIR="/home/administrator/projects/data/logs"

if [ -d "$LOGS_DIR" ]; then
    # Find all log files older than 90 days
    OLD_LOGS=$(find "$LOGS_DIR" -name "*.log" -type f -mtime +90 2>/dev/null || true)

    if [ -n "$OLD_LOGS" ]; then
        OLD_LOG_COUNT=$(echo "$OLD_LOGS" | wc -l)
        # Calculate space before deletion
        OLD_LOG_SIZE=$(echo "$OLD_LOGS" | xargs du -ch 2>/dev/null | tail -1 | awk '{print $1}')

        echo "  Found $OLD_LOG_COUNT log file(s) totaling $OLD_LOG_SIZE"

        if echo "$OLD_LOGS" | xargs rm -f 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Old log files removed"
        else
            echo -e "${RED}✗${NC} Failed to remove some log files"
            ((ERROR_COUNT++))
        fi
    else
        echo -e "${GREEN}✓${NC} No log files older than 90 days"
    fi
else
    echo -e "${YELLOW}⚠${NC} Log directory not found: $LOGS_DIR"
fi
echo ""

#
# 6. CAPTURE FINAL DISK USAGE
#
echo "========================================="
echo "Disk Usage After Cleanup"
echo "========================================="
docker system df
echo ""

SPACE_AFTER=$(docker system df --format "{{.Reclaimable}}" | grep -oP '\d+(\.\d+)?' | head -1 | cut -d. -f1 || echo "0")

# Calculate space freed (rough estimate)
SPACE_FREED=$((SPACE_BEFORE - SPACE_AFTER))

#
# 7. SUMMARY
#
echo "========================================="
echo "Cleanup Summary"
echo "========================================="
echo "Completed: $(date)"
echo "Errors: $ERROR_COUNT"
echo "Approximate space freed: ${SPACE_FREED}GB"
echo ""

if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ Cleanup completed successfully${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Cleanup completed with $ERROR_COUNT error(s)${NC}"
    exit $ERROR_COUNT
fi
