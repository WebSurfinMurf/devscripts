# System Maintenance Scripts

Scripts for managing logs, ephemeral data, and preventing indefinite growth.

## Scripts

### 1. setup-docker-log-rotation.sh
**Purpose:** Configure Docker daemon to automatically rotate all container logs
**Run once:** Sets up system-wide log rotation for all future containers
**Usage:**
```bash
sudo ./setup-docker-log-rotation.sh
```

**Configuration:**
- Max log size: 100MB per file
- Max files: 3 (300MB total per container)
- Compression: enabled
- Applies to: NEW containers only (recreate existing containers to apply)

**After setup:** Recreate containers to apply settings:
```bash
cd /home/administrator/projects/{service}
docker compose down && docker compose up -d
```

---

### 2. cleanup-logs-and-ephemeral-data.sh
**Purpose:** Manual cleanup of logs and ephemeral data
**Run weekly:** Recommended schedule: Sundays at 3 AM
**Usage:**
```bash
# Dry run (preview changes)
sudo ./cleanup-logs-and-ephemeral-data.sh --dry-run

# Actual cleanup
sudo ./cleanup-logs-and-ephemeral-data.sh
```

**What it cleans:**
1. **Docker container logs** - Truncates logs >100MB
2. **GitLab logs** - Deletes logs >30 days old, truncates large logs (>500MB)
3. **Netdata cache** - Removes metadata databases (auto-regenerate)
4. **MongoDB journals** - Removes old WAL files >7 days
5. **Qdrant WAL** - Creates snapshots to flush WAL
6. **Volume backups** - Removes old nested backup directory

**Cron setup:**
```bash
sudo crontab -e

# Add this line:
0 3 * * 0 /home/administrator/projects/devscripts/maintenance/cleanup-logs-and-ephemeral-data.sh
```

---

## Recommended Setup Sequence

### Step 1: Configure Docker Log Rotation (One-time)
```bash
sudo ./setup-docker-log-rotation.sh
```

This prevents future log growth at the Docker level.

### Step 2: Recreate Containers (Optional but recommended)
Apply log rotation to existing containers:
```bash
# For each service:
cd /home/administrator/projects/traefik && docker compose down && docker compose up -d
cd /home/administrator/projects/keycloak && docker compose down && docker compose up -d
# ... etc
```

Or use a script to recreate all:
```bash
for project in /home/administrator/projects/*/; do
    if [ -f "$project/docker-compose.yml" ]; then
        echo "Recreating $(basename $project)..."
        cd "$project"
        docker compose down && docker compose up -d
    fi
done
```

### Step 3: Run Initial Cleanup
```bash
# Test first
sudo ./cleanup-logs-and-ephemeral-data.sh --dry-run

# Then apply
sudo ./cleanup-logs-and-ephemeral-data.sh
```

### Step 4: Schedule Weekly Cleanup
```bash
sudo crontab -e

# Add this line for Sundays at 3 AM:
0 3 * * 0 /home/administrator/projects/devscripts/maintenance/cleanup-logs-and-ephemeral-data.sh
```

---

## What Gets Excluded from Backups

The backup script (`../backup/backup-projects-data.sh`) now excludes:

1. **Netdata cache** (`data/netdata/cache/*.db*`) - Runtime metadata, ~656MB
2. **Volume backups** (`data/volume-backups/*`) - Old nested backups, ~235MB
3. **MongoDB journals** (`data/mongodb/journal/*`) - Ephemeral WAL, ~315MB
4. **GitLab logs** (`data/gitlab/logs/*.log`) - Growing logs, ~100MB+

**Total savings:** ~1.3GB per backup

---

## Monitoring

### Check Docker Log Sizes
```bash
docker ps --format '{{.Names}}' | while read container; do
    log_path=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null)
    if [ -f "$log_path" ]; then
        size=$(du -h "$log_path" | cut -f1)
        echo "$container: $size"
    fi
done | sort -k2 -rh
```

### Check Data Directory Growth
```bash
du -sh /home/administrator/projects/data/* | sort -rh | head -20
```

### Check Backup Sizes
```bash
ls -lhtr /mnt/backup/backups/usr/administrator/projects/data/ | tail -10
```

### Check Cleanup Logs
```bash
ls -lht /home/administrator/projects/devscripts/maintenance/logs/
tail -f /home/administrator/projects/devscripts/maintenance/logs/cleanup-*.log
```

---

## Troubleshooting

### Docker won't restart after log rotation setup
```bash
# Check config syntax
cat /etc/docker/daemon.json | jq .

# Restore backup if needed
sudo cp /etc/docker/daemon.json.backup-* /etc/docker/daemon.json
sudo systemctl restart docker
```

### Container logs still growing
```bash
# Check if container is using new log settings
docker inspect <container_name> | jq '.[0].HostConfig.LogConfig'

# If not, recreate the container:
cd /home/administrator/projects/<service>
docker compose down && docker compose up -d
```

### Cleanup script fails
```bash
# Run in dry-run mode to see what would happen
sudo ./cleanup-logs-and-ephemeral-data.sh --dry-run

# Check the log file for errors
tail -100 logs/cleanup-*.log
```

---

## Files

- `setup-docker-log-rotation.sh` - One-time Docker daemon configuration
- `cleanup-logs-and-ephemeral-data.sh` - Weekly cleanup script
- `logs/` - Cleanup script logs (created automatically)
- `README.md` - This file

---

**Created:** 2025-11-15
**Purpose:** Prevent indefinite log and ephemeral data growth
**Schedule:** Weekly cleanup recommended
