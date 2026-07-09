#!/bin/bash
# finish-disk-cleanup.sh — one-time finisher:
#   1. remove the stale 2026-03-12 GitLab backup tar (~23G)
#   2. install the weekly disk-reclaim cron (Sunday 23:00)
# Run once:  sudo /home/administrator/projects/devscripts/finish-disk-cleanup.sh
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0"; exit 1; }

TAR="/home/administrator/projects/backups/gitlab/1773359254_2026_03_12_18.4.2_gitlab_backup.tar"
CRON_SRC="/home/administrator/projects/devscripts/disk-reclaim.cron"
CRON_DST="/etc/cron.d/disk-reclaim"

echo "== 1. remove stale GitLab backup tar =="
if [ -f "$TAR" ]; then
    SZ="$(du -h "$TAR" | cut -f1)"
    rm -f "$TAR" && echo "   removed ($SZ freed)"
else
    echo "   already gone"
fi

echo "== 2. install weekly disk-reclaim cron (Sunday 23:00) =="
cp "$CRON_SRC" "$CRON_DST"
chmod 644 "$CRON_DST"
echo "   installed:"; grep -vE '^\s*#|^\s*$' "$CRON_DST"

echo "== disk now =="
df -h / | tail -1
echo "done."
