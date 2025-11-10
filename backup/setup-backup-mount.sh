#!/bin/bash
################################################################################
# DEPLOYMENT INSTRUCTIONS FOR AI
################################################################################
# This is the VERSION-CONTROLLED source file.
#
# Location: /home/administrator/projects/devscripts/backup/setup-backup-mount.sh
#
# When making changes:
# 1. Edit THIS file (the one in projects/devscripts/backup/)
# 2. This script deploys itself - just run it with sudo
# 3. No manual copying needed - script is run from this location
#
# Usage: sudo /home/administrator/projects/devscripts/backup/setup-backup-mount.sh
################################################################################

# Setup backup drive for auto-mount on boot with multi-user access
# Device: /dev/sda4 (SanDisk 3.2Gen1, 454.3GB ext4)
#
# This script:
# 1. Creates /mnt/backup mount point
# 2. Adds entry to /etc/fstab for auto-mount on boot
# 3. Mounts the drive
# 4. Creates multi-user directory structure
# 5. Sets proper permissions for each user
# 6. Creates /etc/profile.d/backups.sh for $BACKUPS environment variable

set -e

DEVICE="/dev/sda4"
MOUNT_POINT="/mnt/backup"
FSTAB_ENTRY="$DEVICE  $MOUNT_POINT  ext4  defaults,nofail  0  2"

echo "=== Backup Drive Setup for Auto-Mount ==="
echo "Device: $DEVICE"
echo "Mount point: $MOUNT_POINT"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo "ERROR: Device $DEVICE not found"
    lsblk
    exit 1
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
fi

# Check if fstab entry already exists
if grep -q "$DEVICE" /etc/fstab; then
    echo "⚠ fstab entry for $DEVICE already exists:"
    grep "$DEVICE" /etc/fstab
    echo ""
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Backup fstab
        cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)
        # Remove old entry
        sed -i "\|$DEVICE|d" /etc/fstab
        echo "Old entry removed"
    else
        echo "Keeping existing fstab entry"
    fi
fi

# Add fstab entry if not present
if ! grep -q "$DEVICE" /etc/fstab; then
    echo "Adding fstab entry..."
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "✓ Added to /etc/fstab"
fi

# Mount the drive (if not already mounted)
if mount | grep -q "$MOUNT_POINT"; then
    echo "✓ Drive already mounted at $MOUNT_POINT"
else
    echo "Mounting $DEVICE to $MOUNT_POINT..."
    mount "$MOUNT_POINT"
    echo "✓ Mounted successfully"
fi

# Verify mount
df -h "$MOUNT_POINT"
echo ""

# Create multi-user backup directory structure
echo "Creating multi-user backup structure..."

BACKUP_ROOT="$MOUNT_POINT/backups"
mkdir -p "$BACKUP_ROOT"

# Create user directories with proper permissions
USERS=("administrator" "websurfinmurf" "apprunner" "joe")

for user in "${USERS[@]}"; do
    USER_DIR="$BACKUP_ROOT/usr/$user"
    echo "  Creating: $USER_DIR"
    mkdir -p "$USER_DIR/projects"

    # Set ownership to the user
    chown -R "$user:$user" "$USER_DIR"

    # Set permissions: user has full access, others have no access
    chmod 700 "$USER_DIR"
    chmod 700 "$USER_DIR/projects"
done

# Set backup root to be readable by all (but directories inside are restricted)
chmod 755 "$BACKUP_ROOT"
chmod 755 "$BACKUP_ROOT/usr"

echo ""
echo "✓ Directory structure created:"
tree -L 4 -d "$BACKUP_ROOT" 2>/dev/null || find "$BACKUP_ROOT" -type d

echo ""
echo "✓ Permissions set:"
ls -la "$BACKUP_ROOT/usr/"

echo ""
echo "=== Setup Complete ==="
echo "✓ Drive will auto-mount on boot"
echo "✓ Multi-user structure created at: $BACKUP_ROOT"
echo "✓ Each user has access only to their own directory"
echo ""
echo "Structure:"
echo "  /mnt/backup/backups/usr/{username}/projects/{projectname}/"
echo ""
echo "Users configured:"
for user in "${USERS[@]}"; do
    echo "  - $user: $BACKUP_ROOT/usr/$user/"
done

echo ""
echo "fstab entry:"
grep "$DEVICE" /etc/fstab

echo ""
echo "=== Setting up \$BACKUPS environment variable ==="

# Create profile.d script for BACKUPS variable
PROFILE_FILE="/etc/profile.d/backups.sh"
cat > "$PROFILE_FILE" <<'EOFPROFILE'
# Set BACKUPS environment variable for all users
# Points to user's backup directory on thumb drive
export BACKUPS="/mnt/backup/backups/usr/$USER/projects"
EOFPROFILE

chmod +x "$PROFILE_FILE"
echo "✓ Created $PROFILE_FILE"
echo ""
echo "Each user will have \$BACKUPS set to:"
echo "  /mnt/backup/backups/usr/{username}/projects"
echo ""
echo "Activate in current session: source /etc/profile.d/backups.sh"
