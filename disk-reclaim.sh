#!/bin/bash
# disk-reclaim.sh — weekly ROOT-fs space reclaim (runs as root, Sun night).
#
# Complements cleanserver.sh (admin, Sun 2am, which prunes dangling docker
# images/containers/build-cache). This handles what needs ROOT and cleanserver
# doesn't touch:
#   1. Truncate oversized Docker container json.logs  <-- the 158GB problem
#   2. Truncate GitLab's own oversized logs
#   3. Delete stale GitLab backup tarballs (>30d, always keeps the newest)
#   4. Vacuum the systemd journal
#
# All actions are safe on running services: truncating a live log leaves the
# container writing to the same inode; only historical stdout is dropped (it
# belongs in Loki/journald anyway). Supports --dry-run.
#
# Manual:  sudo /home/administrator/projects/devscripts/disk-reclaim.sh --dry-run
#          sudo /home/administrator/projects/devscripts/disk-reclaim.sh
set -uo pipefail

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
LOG=/var/log/disk-reclaim.log
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0"; exit 1; }
exec > >(tee -a "$LOG") 2>&1

# thresholds
CLOG_MIN=$((100*1024*1024))   # truncate container logs over 100M
GLOG_MIN=$((200*1024*1024))   # truncate gitlab logs over 200M
GBK_DAYS=30                   # delete gitlab backup tars older than 30d (keep newest)
GITLAB_LOGS=/home/administrator/projects/data/gitlab/logs
GITLAB_BK=/home/administrator/projects/backups/gitlab

hr(){ numfmt --to=iec "$1" 2>/dev/null || echo "$1"; }
act(){ [ "$DRY" = 1 ] && echo "  [dry-run] would: $*" || eval "$*"; }

echo "############ disk-reclaim $(date '+%F %T') $([ "$DRY" = 1 ] && echo '(DRY RUN)') ############"
BEFORE=$(df -B1 --output=used / | tail -1)
df -h / | tail -1

echo "== 1. Docker container json.logs over $(hr $CLOG_MIN) =="
if command -v docker >/dev/null 2>&1; then
  for c in $(docker ps -aq 2>/dev/null); do
    lp=$(docker inspect --format '{{.LogPath}}' "$c" 2>/dev/null) || continue
    [ -n "$lp" ] && [ -f "$lp" ] || continue
    sz=$(stat -c %s "$lp" 2>/dev/null || echo 0)
    if [ "$sz" -gt "$CLOG_MIN" ]; then
      nm=$(docker inspect --format '{{.Name}}' "$c" 2>/dev/null | sed 's#^/##')
      echo "  $nm: $(hr $sz)"
      act ": > \"$lp\""
    fi
  done
else echo "  (docker not available)"; fi

echo "== 2. GitLab logs over $(hr $GLOG_MIN) =="
if [ -d "$GITLAB_LOGS" ]; then
  while IFS= read -r -d '' f; do
    sz=$(stat -c %s "$f"); echo "  $(hr $sz)  $f"; act ": > \"$f\""
  done < <(find "$GITLAB_LOGS" -type f -name '*.log' -size +${GLOG_MIN}c -print0 2>/dev/null)
else echo "  (no $GITLAB_LOGS)"; fi

echo "== 3. Stale GitLab backup tarballs (>${GBK_DAYS}d, keep newest) =="
if [ -d "$GITLAB_BK" ]; then
  newest=$(ls -1t "$GITLAB_BK"/*_gitlab_backup.tar 2>/dev/null | head -1)
  while IFS= read -r f; do
    [ "$f" = "$newest" ] && { echo "  keep newest: $(basename "$f")"; continue; }
    echo "  delete: $(basename "$f") ($(hr $(stat -c %s "$f")))"; act "rm -f \"$f\""
  done < <(find "$GITLAB_BK" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -mtime +${GBK_DAYS} 2>/dev/null)
else echo "  (no $GITLAB_BK)"; fi

echo "== 4. Journal vacuum (keep 200M) =="
act "journalctl --vacuum-size=200M"

sync
AFTER=$(df -B1 --output=used / | tail -1)
echo "== result =="
df -h / | tail -1
[ "$DRY" = 0 ] && echo "reclaimed: $(hr $((BEFORE-AFTER)))"
echo "############ done $([ "$DRY" = 1 ] && echo '(dry run — nothing changed)') ############"
