#!/bin/bash
################################################################################
# DEPLOYMENT INSTRUCTIONS FOR AI
################################################################################
# This is the VERSION-CONTROLLED source file.
#
# Location: /home/administrator/projects/devscripts/backup/mount-backup-drive.sh
#
# When making changes:
# 1. Edit THIS file (the one in projects/devscripts/backup/)
# 2. This script is used directly from this location - no copying needed
# 3. This is a LEGACY/MANUAL mount script - setup-backup-mount.sh is preferred
#
# Usage: sudo /home/administrator/projects/devscripts/backup/mount-backup-drive.sh
#
# Note: This script is DEPRECATED. Use setup-backup-mount.sh for initial setup,
#       which configures auto-mount via fstab. This script is kept for manual
#       mounting if needed.
################################################################################

# Mount backup thumb drive to /mnt/backup
# Device: /dev/sda4 (SanDisk 3.2Gen1, 454.3GB ext4)
#
# This script requires root/sudo access

set -e

DEVICE="/dev/sda4"
MOUNT_POINT="/mnt/backup"

echo "=== Backup Drive Mount Script ==="
echo "Device: $DEVICE"
echo "Mount point: $MOUNT_POINT"
echo ""

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo "ERROR: Device $DEVICE not found"
    echo "Run 'lsblk' to check available devices"
    exit 1
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point: $MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "✓ Drive is already mounted at $MOUNT_POINT"
    df -h "$MOUNT_POINT"
    exit 0
fi

# Mount the device
echo "Mounting $DEVICE to $MOUNT_POINT..."
sudo mount "$DEVICE" "$MOUNT_POINT"

# Set ownership to administrator
echo "Setting ownership to administrator:administrators..."
sudo chown administrator:administrators "$MOUNT_POINT"

# Verify mount
echo ""
echo "✓ Mount successful!"
df -h "$MOUNT_POINT"

echo ""
echo "Mount point ready: $MOUNT_POINT"
