#!/bin/bash
# speedtest-ssd4tb.sh — sequential (and random, if fio) benchmark of /mnt/ssd4tb.
# Writes a temp file, measures, and removes it. Safe/read-mostly; touches only
# its own temp file under the mount. Run as root: sudo ./speedtest-ssd4tb.sh
set -uo pipefail
MNT=/mnt/ssd4tb
SIZE_GB=10
TF="$MNT/.speedtest.$$"

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0"; exit 1; }
findmnt "$MNT" >/dev/null || { echo "$MNT not mounted"; exit 1; }
cleanup(){ rm -f "$TF"; }
trap cleanup EXIT

echo "=== benchmark $MNT  ($(findmnt -no SOURCE "$MNT")) ==="
if command -v fio >/dev/null 2>&1; then
    echo "-- fio sequential WRITE (1MiB, direct) --"
    fio --name=w --filename="$TF" --size=${SIZE_GB}G --bs=1M --rw=write --direct=1 \
        --ioengine=libaio --iodepth=16 --end_fsync=1 --group_reporting 2>/dev/null | grep -iE 'WRITE:'
    echo "-- fio sequential READ (1MiB, direct) --"
    fio --name=r --filename="$TF" --size=${SIZE_GB}G --bs=1M --rw=read --direct=1 \
        --ioengine=libaio --iodepth=16 --group_reporting 2>/dev/null | grep -iE 'READ:'
    echo "-- fio random READ 4k (IOPS) --"
    fio --name=rr --filename="$TF" --size=${SIZE_GB}G --bs=4k --rw=randread --direct=1 \
        --ioengine=libaio --iodepth=32 --numjobs=4 --group_reporting 2>/dev/null | grep -iE 'read:|IOPS'
else
    echo "(fio not installed — dd fallback; 'apt install fio' for IOPS/random)"
    echo "-- dd sequential WRITE (${SIZE_GB}G, direct) --"
    dd if=/dev/zero of="$TF" bs=1M count=$((SIZE_GB*1024)) oflag=direct status=progress 2>&1 | tail -1
    sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    echo "-- dd sequential READ (direct) --"
    dd if="$TF" of=/dev/null bs=1M iflag=direct status=progress 2>&1 | tail -1
fi
echo "=== done (temp file removed) ==="
