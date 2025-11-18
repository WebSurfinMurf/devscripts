#!/bin/bash
################################################################################
# Docker Log Rotation Setup
################################################################################
# Purpose: Configure Docker daemon to automatically rotate container logs
# Usage: sudo ./setup-docker-log-rotation.sh
# Effect: All containers will have logs automatically rotated
#         - Max size per log file: 100MB
#         - Max log files kept: 3 (total 300MB per container)
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Docker Log Rotation Setup ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Please run as root (use sudo)${NC}"
    exit 1
fi

DOCKER_CONFIG="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.backup-$(date +%Y%m%d-%H%M%S)"

# Backup existing config
if [ -f "$DOCKER_CONFIG" ]; then
    echo -e "${YELLOW}→ Backing up existing config to $BACKUP_FILE${NC}"
    cp "$DOCKER_CONFIG" "$BACKUP_FILE"
fi

# Create new config with log rotation
echo -e "${BLUE}→ Configuring Docker log rotation...${NC}"
cat > "$DOCKER_CONFIG" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3",
    "compress": "true"
  }
}
EOF

echo -e "${GREEN}✓ Docker daemon config updated${NC}"
echo ""

# Show config
echo -e "${BLUE}New configuration:${NC}"
cat "$DOCKER_CONFIG"
echo ""

# Restart Docker
echo -e "${YELLOW}→ Restarting Docker daemon...${NC}"
systemctl restart docker

# Wait for Docker to be ready
sleep 5

# Verify Docker is running
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker daemon restarted successfully${NC}"
else
    echo -e "${RED}✗ Docker daemon failed to restart${NC}"
    echo -e "${YELLOW}→ Restoring backup...${NC}"
    cp "$BACKUP_FILE" "$DOCKER_CONFIG"
    systemctl restart docker
    exit 1
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${BLUE}Configuration applied:${NC}"
echo "  - Log driver: json-file"
echo "  - Max log size: 100MB per file"
echo "  - Max files: 3 (300MB total per container)"
echo "  - Compression: enabled"
echo ""
echo -e "${YELLOW}Note: This only applies to NEW containers.${NC}"
echo -e "${YELLOW}Existing containers will continue using their old log settings.${NC}"
echo -e "${YELLOW}To apply to existing containers, recreate them (docker compose down && docker compose up -d).${NC}"
