#!/bin/bash
# Daily backup of ~/.claude/ to /mnt/backup with 4-day rotation
set -e

BACKUP_BASE="/mnt/backup/backups/usr/$(whoami)/claude-config"
DATE=$(date +%Y%m%d)
BACKUP_DIR="${BACKUP_BASE}/${DATE}"
KEEP_DAYS=4

mkdir -p "$BACKUP_DIR"

rsync -a --delete \
  --exclude="shell-snapshots/" \
  --exclude="debug/" \
  --exclude="cache/" \
  --exclude="statsig/" \
  ~/.claude/ "$BACKUP_DIR/"

echo "$(date): Backed up ~/.claude/ to $BACKUP_DIR" >> "${BACKUP_BASE}/backup.log"

# Rotate: delete backups older than KEEP_DAYS
find "$BACKUP_BASE" -maxdepth 1 -type d -name "20*" -mtime +${KEEP_DAYS} -exec rm -rf {} \;

echo "$(date): Rotated old backups (keeping ${KEEP_DAYS} days)" >> "${BACKUP_BASE}/backup.log"
