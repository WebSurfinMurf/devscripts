#!/bin/bash
# format-ssd4tb.sh — SAFELY format the 4TB Kingston SSD as ext4.
#
# Targets the Kingston ONLY by its unique by-id/serial — never a /dev/nvmeXn1
# name. Every probe FAILS CLOSED (a probe error aborts, never "passes"). All
# identity+safety guards run twice: once for display, and AGAIN immediately
# before the destructive write (closes the TOCTOU window across the prompt).
# The partition handed to mkfs is re-verified to belong to the same disk.
#
# Hardened 2026-07-06 after Review Board (Codex) safety review.
# Run as root:  sudo /home/administrator/projects/devscripts/format-ssd4tb.sh
set -euo pipefail

# ===== TARGET IDENTITY =====
BYID="/dev/disk/by-id/nvme-KINGSTON_SFYRD4000G_50026B7686F902F0"
EXPECT_SERIAL="50026B7686F902F0"
EXPECT_MODEL="KINGSTON SFYRD4000G"          # exact match (trimmed)
EXPECT_MIN_BYTES=3500000000000              # 3.5 TB
EXPECT_MAX_BYTES=4200000000000              # 4.2 TB
FORBID_SERIALS=("24484C51E555" "03028019011025204816")   # root NVMe + backup thumb

# ===== OUTPUT CONFIG =====
LABEL="ssd4tb"
MOUNT="/mnt/ssd4tb"

DEV="" SER="" MOD="" BYTES=""
die(){ echo "ABORT: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run as root: sudo $0"
command -v parted >/dev/null || { echo "installing parted..."; apt-get update -qq && apt-get install -y parted; }

# Resolve target and run ALL guards. Every probe checked for success (fail-closed).
resolve_and_guard() {
    [ -e "$BYID" ] || die "$BYID not present — is the Kingston plugged in?"
    DEV="$(readlink -f "$BYID")" || die "cannot resolve $BYID"
    [ -b "$DEV" ] || die "$DEV is not a block device"

    local TYPE MPS CHILDREN WF
    TYPE="$(lsblk -dno TYPE "$DEV")"   || die "TYPE probe failed on $DEV"
    [ "$TYPE" = "disk" ]               || die "guard1: $DEV is not a whole disk (type=$TYPE)"

    SER="$(lsblk -dno SERIAL "$DEV")"  || die "SERIAL probe failed on $DEV"
    [ -n "$SER" ]                      || die "guard2: empty serial on $DEV"
    [ "$SER" = "$EXPECT_SERIAL" ]      || die "guard2: serial mismatch ('$SER' != '$EXPECT_SERIAL')"

    MOD="$(lsblk -dno MODEL "$DEV" | sed 's/[[:space:]]*$//')" || die "MODEL probe failed on $DEV"
    [ "$MOD" = "$EXPECT_MODEL" ]       || die "guard3: model mismatch ('$MOD' != '$EXPECT_MODEL')"

    local s; for s in "${FORBID_SERIALS[@]}"; do [ "$SER" = "$s" ] && die "guard4: forbidden serial $s"; done

    BYTES="$(blockdev --getsize64 "$DEV")" || die "size probe failed on $DEV"
    { [ "$BYTES" -ge "$EXPECT_MIN_BYTES" ] && [ "$BYTES" -le "$EXPECT_MAX_BYTES" ]; } \
        || die "guard5: size $BYTES outside 3.5-4.2TB"

    # guard6: not mounted / no open holders (fail closed on probe error)
    MPS="$(lsblk -no MOUNTPOINT "$DEV")" || die "MOUNTPOINT probe failed on $DEV"
    [ -z "$(printf '%s' "$MPS" | tr -d ' \n')" ] || { echo "$MPS" >&2; die "guard6: $DEV has a mounted partition"; }
    if grep -q "^$DEV" /proc/mounts; then die "guard6: $DEV appears in /proc/mounts"; fi

    # guard7: blank — no partitions/holders, no fs signatures (fail closed)
    CHILDREN="$(lsblk -no NAME "$DEV" | tail -n +2)" || die "children probe failed on $DEV"
    [ -z "$CHILDREN" ] || { echo "$CHILDREN" >&2; die "guard7: $DEV has partitions/holders — not blank"; }
    WF="$(wipefs "$DEV")" || die "wipefs probe failed on $DEV"
    [ -z "$(printf '%s' "$WF" | tail -n +2)" ] || { echo "$WF" >&2; die "guard7: $DEV has fs signatures"; }
}

echo "== resolve + guard (pass 1: display) =="
resolve_and_guard
echo "  all guards passed on $DEV (serial $SER)"

echo
echo "================= ABOUT TO FORMAT (DESTRUCTIVE) ================="
echo "  Device : $DEV   ($BYID)"
echo "  Model  : $MOD"
echo "  Serial : $SER"
echo "  Size   : $(numfmt --to=iec "$BYTES" 2>/dev/null || echo "$BYTES bytes")"
echo "  Plan   : GPT + one ext4 partition, label '$LABEL', mount $MOUNT"
echo "  (root disk & backup thumb serials are on the forbidden list)"
echo "================================================================"
read -r -p "Type the serial ($EXPECT_SERIAL) to confirm: " ANS
[ "$ANS" = "$EXPECT_SERIAL" ] || die "confirmation mismatch — nothing changed."

echo "== resolve + guard (pass 2: re-validate right before write — closes TOCTOU) =="
resolve_and_guard
echo "  re-validated $DEV (serial $SER); still blank."

echo "== partition (GPT, single, aligned) — on the by-id path =="
parted -s "$BYID" mklabel gpt
parted -s "$BYID" mkpart primary ext4 0% 100%
udevadm settle 2>/dev/null || true; partprobe "$DEV" 2>/dev/null || true; sleep 2

echo "== locate + STRICTLY verify the new partition (no unsafe fallback) =="
PART="${BYID}-part1"
[ -e "$PART" ] || die "partition symlink $PART did not appear — aborting (refusing kernel-name fallback)"
RPART="$(readlink -f "$PART")" || die "cannot resolve $PART"
[ -b "$RPART" ] || die "$RPART is not a block device"
[ "$(lsblk -dno TYPE "$RPART")" = "part" ] || die "$RPART is not a partition"
PKN="$(lsblk -no PKNAME "$RPART" | head -1)" || die "PKNAME probe failed on $RPART"
[ -n "$PKN" ] || die "no parent for $RPART"
PARENT="/dev/$PKN"
# the partition's parent MUST be the same disk (same serial) we just partitioned
PSER="$(lsblk -dno SERIAL "$PARENT")" || die "parent serial probe failed"
[ "$PSER" = "$EXPECT_SERIAL" ] || die "partition parent serial mismatch ('$PSER' != '$EXPECT_SERIAL') — refusing mkfs"
echo "  partition $RPART on parent $PARENT (serial $PSER) — verified."

echo "== mkfs.ext4 (label $LABEL, -m 0) =="
mkfs.ext4 -L "$LABEL" -m 0 "$RPART"
UUID="$(blkid -s UUID -o value "$RPART")" || die "could not read UUID"
echo "  UUID: $UUID"

echo "== fstab (by UUID, nofail) + mount =="
mkdir -p "$MOUNT"
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID  $MOUNT  ext4  defaults,nofail,x-systemd.device-timeout=10  0  2" >> /etc/fstab
mount "$MOUNT"

echo "== verify =="
findmnt "$MOUNT" && df -h "$MOUNT" | tail -1
echo "DONE — $MOUNT is ext4 and mounted. (Backup migration still parked.)"
