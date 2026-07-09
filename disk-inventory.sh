#!/bin/bash
# disk-inventory.sh — read-only inventory of the ROOT filesystem
# (/dev/mapper/ubuntu--vg-ubuntu--lv on nvme0n1) to find what's using space and
# what could be moved off (e.g. to /mnt/ssd4tb). Writes a log for review.
# Run as root:  sudo /home/administrator/projects/devscripts/disk-inventory.sh
set -uo pipefail
LOG=/home/administrator/projects/backups/disk-inventory.log
: > "$LOG"; exec > >(tee -a "$LOG") 2>&1
[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0"; exit 1; }

echo "############ disk inventory $(date '+%F %T') ############"
echo "(du -x stays on the root filesystem only — mounted drives are excluded)"

echo; echo "======== 1. FILESYSTEM USAGE ========"
df -h / /boot /mnt/backup /mnt/ssd4tb /mnt/shared 2>/dev/null

echo; echo "======== 2. TOP-LEVEL CONSUMERS (root fs) ========"
du -xh --max-depth=1 / 2>/dev/null | sort -rh | head -25

echo; echo "======== 3. DOCKER (images / containers / volumes / build cache) ========"
docker system df 2>/dev/null || echo "(docker not available)"
echo "-- /var/lib/docker total --"; du -xsh /var/lib/docker 2>/dev/null
echo "-- largest docker volumes --"; du -xh --max-depth=1 /var/lib/docker/volumes 2>/dev/null | sort -rh | head -15
echo "-- largest overlay2 layers --"; du -xh --max-depth=1 /var/lib/docker/overlay2 2>/dev/null | sort -rh | head -8

echo; echo "======== 4. projects/data (application data) ========"
du -h --max-depth=2 /home/administrator/projects/data 2>/dev/null | sort -rh | head -30

echo; echo "======== 5. /var breakdown ========"
du -xh --max-depth=2 /var 2>/dev/null | sort -rh | head -20

echo; echo "======== 6. HOME directories ========"
du -xsh /home/* /root 2>/dev/null | sort -rh

echo; echo "======== 7. SNAP ========"
du -xsh /var/lib/snapd 2>/dev/null; echo "snaps: $(snap list 2>/dev/null | tail -n +2 | wc -l)"

echo; echo "======== 8. JOURNAL + LOGS ========"
journalctl --disk-usage 2>/dev/null; du -xsh /var/log 2>/dev/null

echo; echo "======== 9. PACKAGE / MISC CACHES ========"
du -xsh /var/cache/apt /var/cache /tmp /var/tmp 2>/dev/null

echo; echo "======== 10. LARGEST INDIVIDUAL FILES (>500M, root fs) ========"
find / -xdev -type f -size +500M -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -30 \
  | awk '{printf "%6.1f GB  %s\n", $1/1073741824, $2}'

echo; echo "############ done — log: $LOG ############"
