#!/bin/bash
################################################################################
# Migrate Database Docker Volumes to projects/data/
################################################################################
# Location: /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh
#
# Purpose: Migrates databases from Docker volumes to projects/data/ directories
# This makes all database data consistent with the backup system.
#
# Databases to migrate:
# - PostgreSQL (postgres_data → projects/data/postgres)
# - TimescaleDB (timescaledb_data → projects/data/timescaledb)
# - Redis (redis_data → projects/data/redis)
# - MongoDB (mongodb_data + mongodb_config → projects/data/mongodb)
#
# Usage: sudo ./migrate-db-to-projectsdata.sh <database-name>
#        sudo ./migrate-db-to-projectsdata.sh all
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Configuration
DATA_ROOT="/home/administrator/projects/data"
BACKUP_ROOT="/home/administrator/projects/data/volume-backups"

# Function to migrate a database
migrate_database() {
    local DB_NAME=$1
    local CONTAINER_NAME=$2
    local VOLUME_NAME=$3
    local DATA_DIR=$4
    local EXTRA_VOLUMES=$5  # Optional: additional volumes (e.g., mongodb_config)

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Migrating: $DB_NAME${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Step 1: Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}⊘ Container $CONTAINER_NAME not found, skipping${NC}"
        echo ""
        return
    fi

    # Step 2: Check if volume exists
    if ! docker volume ls --format '{{.Name}}' | grep -q "^${VOLUME_NAME}$"; then
        echo -e "${YELLOW}⊘ Volume $VOLUME_NAME not found, skipping${NC}"
        echo ""
        return
    fi

    # Step 3: Create target directory
    echo -e "${GREEN}→ Creating target directory: $DATA_DIR${NC}"
    mkdir -p "$DATA_DIR"
    chown administrator:administrators "$DATA_DIR"

    # Step 4: Stop container
    echo -e "${GREEN}→ Stopping container: $CONTAINER_NAME${NC}"
    docker stop "$CONTAINER_NAME"

    # Step 5: Backup current data (safety)
    echo -e "${GREEN}→ Creating safety backup of volume${NC}"
    mkdir -p "$BACKUP_ROOT"
    BACKUP_FILE="$BACKUP_ROOT/${VOLUME_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"

    docker run --rm \
        -v "${VOLUME_NAME}:/source:ro" \
        -v "${BACKUP_ROOT}:/backup" \
        alpine tar czf "/backup/$(basename $BACKUP_FILE)" -C /source .

    echo -e "${GREEN}  ✓ Backup saved: $BACKUP_FILE${NC}"

    # Step 6: Copy data from volume to directory
    echo -e "${GREEN}→ Copying data from volume to $DATA_DIR${NC}"
    docker run --rm \
        -v "${VOLUME_NAME}:/source:ro" \
        -v "${DATA_DIR}:/target" \
        alpine sh -c "cp -a /source/. /target/"

    echo -e "${GREEN}  ✓ Data copied successfully${NC}"

    # Step 7: Handle extra volumes (e.g., mongodb_config)
    if [ -n "$EXTRA_VOLUMES" ]; then
        for EXTRA in $EXTRA_VOLUMES; do
            EXTRA_VOLUME="${EXTRA%:*}"
            EXTRA_SUBDIR="${EXTRA#*:}"
            EXTRA_DIR="${DATA_DIR}/${EXTRA_SUBDIR}"

            echo -e "${GREEN}→ Copying extra volume: $EXTRA_VOLUME to $EXTRA_DIR${NC}"
            mkdir -p "$EXTRA_DIR"

            docker run --rm \
                -v "${EXTRA_VOLUME}:/source:ro" \
                -v "${EXTRA_DIR}:/target" \
                alpine sh -c "cp -a /source/. /target/"

            echo -e "${GREEN}  ✓ Extra volume copied${NC}"
        done
    fi

    # Step 8: Fix permissions
    echo -e "${GREEN}→ Setting ownership to administrator:administrators${NC}"
    chown -R administrator:administrators "$DATA_DIR"

    # Step 9: Show summary
    VOLUME_SIZE=$(docker run --rm -v "${VOLUME_NAME}:/data:ro" alpine du -sh /data | cut -f1)
    NEW_SIZE=$(du -sh "$DATA_DIR" | cut -f1)

    echo ""
    echo -e "${GREEN}✓ Migration completed successfully${NC}"
    echo "  Original volume size: $VOLUME_SIZE"
    echo "  New directory size: $NEW_SIZE"
    echo "  Location: $DATA_DIR"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT NEXT STEPS:${NC}"
    echo "  1. Update docker-compose.yml or deploy script to use bind mount:"
    echo "     volumes:"
    echo "       - $DATA_DIR:/path/in/container"
    echo "  2. Test the container starts and data is accessible"
    echo "  3. If successful, remove the old volume:"
    echo "     docker volume rm $VOLUME_NAME"
    if [ -n "$EXTRA_VOLUMES" ]; then
        for EXTRA in $EXTRA_VOLUMES; do
            EXTRA_VOLUME="${EXTRA%:*}"
            echo "     docker volume rm $EXTRA_VOLUME"
        done
    fi
    echo ""
}

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 <database-name|all>"
    echo ""
    echo "Available databases:"
    echo "  postgres     - PostgreSQL"
    echo "  timescaledb  - TimescaleDB"
    echo "  redis        - Redis"
    echo "  mongodb      - MongoDB"
    echo "  all          - Migrate all databases"
    exit 1
fi

DB_CHOICE=$1

case "$DB_CHOICE" in
    postgres)
        migrate_database "PostgreSQL" "postgres" "postgres_data" "$DATA_ROOT/postgres"
        ;;

    timescaledb)
        migrate_database "TimescaleDB" "timescaledb" "timescaledb_data" "$DATA_ROOT/timescaledb"
        ;;

    redis)
        migrate_database "Redis" "redis" "redis_data" "$DATA_ROOT/redis"
        ;;

    mongodb)
        migrate_database "MongoDB" "mongodb" "mongodb_data" "$DATA_ROOT/mongodb" "mongodb_config:config"
        ;;

    all)
        echo -e "${BLUE}========================================"
        echo "Migrating ALL databases to projects/data/"
        echo -e "========================================${NC}"
        echo ""

        migrate_database "PostgreSQL" "postgres" "postgres_data" "$DATA_ROOT/postgres"
        migrate_database "TimescaleDB" "timescaledb" "timescaledb_data" "$DATA_ROOT/timescaledb"
        migrate_database "Redis" "redis" "redis_data" "$DATA_ROOT/redis"
        migrate_database "MongoDB" "mongodb" "mongodb_data" "$DATA_ROOT/mongodb" "mongodb_config:config"

        echo -e "${GREEN}========================================"
        echo "All migrations completed!"
        echo -e "========================================${NC}"
        echo ""
        echo -e "${YELLOW}NEXT STEPS:${NC}"
        echo "1. Update each database's docker-compose.yml or deploy script"
        echo "2. Test each database individually"
        echo "3. Remove old Docker volumes once confirmed working"
        echo ""
        echo "Safety backups stored in: $BACKUP_ROOT"
        ;;

    *)
        echo -e "${RED}ERROR: Unknown database: $DB_CHOICE${NC}"
        echo "Use: postgres, timescaledb, redis, mongodb, or all"
        exit 1
        ;;
esac
