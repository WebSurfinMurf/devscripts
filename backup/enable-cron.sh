#!/bin/bash
################################################################################
# DEPLOYMENT INSTRUCTIONS FOR AI
################################################################################
# This is the VERSION-CONTROLLED source file.
#
# Location: /home/administrator/projects/devscripts/backup/enable-cron.sh
#
# When making changes:
# 1. Edit THIS file (the one in projects/devscripts/backup/)
# 2. This script is used directly from this location
#
# Usage: sudo /home/administrator/projects/devscripts/backup/enable-cron.sh
################################################################################

# Enable daily backup cron job (4 AM)
# Deploys backup-cron.template to /etc/cron.d/backup-projects

set -e

TEMPLATE="/home/administrator/projects/devscripts/backup/backup-cron.template"
CRON_FILE="/etc/cron.d/backup-projects"

echo "=== Enable Automated Backups ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if template exists
if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template not found: $TEMPLATE"
    exit 1
fi

# Check if cron job already exists
if [ -f "$CRON_FILE" ]; then
    echo "⚠ Cron job already exists: $CRON_FILE"
    echo ""
    cat "$CRON_FILE"
    echo ""
    read -p "Replace with updated version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
fi

# Deploy cron job
echo "Deploying cron job..."
cp "$TEMPLATE" "$CRON_FILE"
chmod 644 "$CRON_FILE"

echo "✓ Cron job deployed: $CRON_FILE"
echo ""
echo "Content:"
cat "$CRON_FILE"
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Automated backups are now enabled:"
echo "  Schedule: Daily at 4:00 AM"
echo "  Script: /home/administrator/projects/devscripts/backup/backup-projects-data.sh"
echo "  Log: /var/log/backup-cron.log"
echo ""
echo "To disable:"
echo "  sudo rm $CRON_FILE"
echo ""
echo "To test manually:"
echo "  sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh"
