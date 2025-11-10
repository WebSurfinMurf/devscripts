#!/bin/bash
################################################################################
# DEPLOYMENT INSTRUCTIONS FOR AI
################################################################################
# This is the VERSION-CONTROLLED source file.
#
# Location: /home/administrator/projects/devscripts/backup/setup-backup-env.sh
#
# When making changes:
# 1. Edit THIS file (the one in projects/devscripts/backup/)
# 2. This script deploys itself - just run it with sudo
# 3. No manual copying needed - script is run from this location
#
# Usage: sudo /home/administrator/projects/devscripts/backup/setup-backup-env.sh
#
# Note: This is a STANDALONE script for setting up $BACKUPS environment variable only.
#       The main setup-backup-mount.sh script includes this functionality.
#       Use this if you only need to update/fix the environment variable.
################################################################################

# Setup $BACKUPS environment variable for all users
# Sets: BACKUPS=/mnt/backup/backups/usr/{username}/projects/
#
# This script creates /etc/profile.d/backups.sh which sets the variable
# on login for all users

set -e

PROFILE_FILE="/etc/profile.d/backups.sh"

echo "=== Setting up \$BACKUPS environment variable ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Create the profile script
echo "Creating $PROFILE_FILE..."
cat > "$PROFILE_FILE" <<'EOF'
# Set BACKUPS environment variable for all users
# Points to user's backup directory on thumb drive
export BACKUPS="/mnt/backup/backups/usr/$USER/projects"
EOF

# Make it executable
chmod +x "$PROFILE_FILE"

echo "✓ Created $PROFILE_FILE"
echo ""
echo "Content:"
cat "$PROFILE_FILE"
echo ""
echo "=== Setup Complete ==="
echo ""
echo "The \$BACKUPS variable will be set for all users on their next login."
echo ""
echo "Each user will have:"
echo "  administrator: BACKUPS=/mnt/backup/backups/usr/administrator/projects"
echo "  websurfinmurf: BACKUPS=/mnt/backup/backups/usr/websurfinmurf/projects"
echo "  apprunner:     BACKUPS=/mnt/backup/backups/usr/apprunner/projects"
echo "  joe:           BACKUPS=/mnt/backup/backups/usr/joe/projects"
echo ""
echo "Usage examples:"
echo "  echo \$BACKUPS"
echo "  ls \$BACKUPS"
echo "  rsync -avh ~/projects/data/ \$BACKUPS/data/"
echo ""
echo "To activate in current session without re-login:"
echo "  source /etc/profile.d/backups.sh"
echo "  echo \$BACKUPS"
