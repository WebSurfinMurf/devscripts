# Database Migration Guide: Docker Volumes → projects/data/

## Overview

This guide migrates database storage from Docker volumes to `projects/data/` directories for consistency with the backup system.

**Created:** 2025-11-10
**Purpose:** Consolidate all database data under `projects/data/`

## Why Migrate?

### Current State (Inconsistent)
```
✅ Qdrant:    /home/administrator/projects/data/qdrant
✅ ArangoDB:  /home/administrator/projects/data/arangodb
❌ PostgreSQL: /var/lib/docker/volumes/postgres_data/_data
❌ TimescaleDB: /var/lib/docker/volumes/timescaledb_data/_data
❌ Redis: /var/lib/docker/volumes/redis_data/_data
❌ MongoDB: /var/lib/docker/volumes/mongodb_data/_data
```

### After Migration (Consistent)
```
✅ PostgreSQL:  /home/administrator/projects/data/postgres
✅ TimescaleDB: /home/administrator/projects/data/timescaledb
✅ Redis:       /home/administrator/projects/data/redis
✅ MongoDB:     /home/administrator/projects/data/mongodb
✅ Qdrant:      /home/administrator/projects/data/qdrant (already there)
✅ ArangoDB:    /home/administrator/projects/data/arangodb (already there)
```

### Benefits
1. **Single backup location** - All data under `projects/data/`
2. **Consistency** - All databases follow same pattern
3. **Easier management** - Know exactly where data lives
4. **Better backups** - One tar archive captures everything
5. **Easier migrations** - Move entire data directory
6. **Clear ownership** - All owned by administrator user

## Migration Process

### Overview
For each database:
1. Stop container
2. Create safety backup of Docker volume
3. Copy data from volume to `projects/data/{database}/`
4. Update docker-compose.yml or deploy script
5. Restart container with new mount
6. Verify data is accessible
7. Remove old Docker volume

### Estimated Downtime
- **PostgreSQL**: 2-5 minutes
- **TimescaleDB**: 2-5 minutes
- **Redis**: 1-2 minutes
- **MongoDB**: 2-5 minutes

**Total if done sequentially:** ~10-20 minutes
**Can be done one at a time** to minimize impact

## Step-by-Step Migration

### Preparation

1. **Schedule maintenance window** (recommend low-traffic period)
2. **Notify services** that databases will be briefly unavailable
3. **Ensure enough disk space**:
   ```bash
   # Check current volume sizes
   docker volume ls
   docker system df -v

   # Check available space in projects/data/
   df -h /home/administrator/projects/data
   ```

### Migration Script Usage

```bash
# Migrate single database
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh postgres
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh timescaledb
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh redis
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh mongodb

# Or migrate all at once
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh all
```

## Database-Specific Instructions

### 1. PostgreSQL Migration

**Step 1: Run migration script**
```bash
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh postgres
```

**Step 2: Update docker-compose.yml**
```bash
cd /home/administrator/projects/postgres
```

Edit `docker-compose.yml` and change:
```yaml
# OLD
volumes:
  - postgres_data:/var/lib/postgresql/data

# NEW
volumes:
  - /home/administrator/projects/data/postgres:/var/lib/postgresql/data
```

Also update the volumes section at the bottom:
```yaml
# OLD
volumes:
  postgres_data:

# NEW (remove the volume definition entirely)
```

**Step 3: Restart container**
```bash
docker compose up -d
```

**Step 4: Verify**
```bash
# Check container started
docker ps | grep postgres

# Check databases are accessible
docker exec postgres psql -U admin -d postgres -c "\l"

# Verify data location
docker inspect postgres --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' | grep postgresql
```

**Step 5: Remove old volume (once confirmed)**
```bash
docker volume rm postgres_data
```

---

### 2. TimescaleDB Migration

**Step 1: Run migration script**
```bash
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh timescaledb
```

**Step 2: Update docker-compose.yml**
```bash
cd /home/administrator/projects/timescaledb
```

Edit `docker-compose.yml` and change:
```yaml
# OLD
volumes:
  - timescaledb_data:/var/lib/postgresql/data

# NEW
volumes:
  - /home/administrator/projects/data/timescaledb:/var/lib/postgresql/data
```

Remove volume definition:
```yaml
# Remove this section
volumes:
  timescaledb_data:
```

**Step 3: Restart container**
```bash
docker compose up -d
```

**Step 4: Verify**
```bash
docker ps | grep timescaledb
docker exec timescaledb psql -U tsdbadmin -d postgres -c "\l"
docker inspect timescaledb --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' | grep postgresql
```

**Step 5: Remove old volume**
```bash
docker volume rm timescaledb_data
```

---

### 3. Redis Migration

**Step 1: Run migration script**
```bash
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh redis
```

**Step 2: Update docker-compose.yml**
```bash
cd /home/administrator/projects/redis
```

Edit `docker-compose.yml` and change:
```yaml
# OLD
volumes:
  - redis_data:/data

# NEW
volumes:
  - /home/administrator/projects/data/redis:/data
```

Remove volume definition:
```yaml
# Remove this section
volumes:
  redis_data:
```

**Step 3: Restart container**
```bash
docker compose up -d
```

**Step 4: Verify**
```bash
docker ps | grep redis

# Test connection (use password from secrets/redis.env)
source /home/administrator/secrets/redis.env
docker exec redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning PING

# Check data location
docker inspect redis --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' | grep /data
```

**Step 5: Remove old volume**
```bash
docker volume rm redis_data
```

---

### 4. MongoDB Migration

**Note:** MongoDB has TWO volumes (data + config)

**Step 1: Run migration script**
```bash
sudo /home/administrator/projects/devscripts/backup/migrate-db-to-projectsdata.sh mongodb
```

This creates:
- `/home/administrator/projects/data/mongodb/` (main data)
- `/home/administrator/projects/data/mongodb/config/` (config data)

**Step 2: Update docker-compose.yml**
```bash
cd /home/administrator/projects/mongodb
```

Edit `docker-compose.yml` and change:
```yaml
# OLD
volumes:
  - mongodb_data:/data/db
  - mongodb_config:/data/configdb

# NEW
volumes:
  - /home/administrator/projects/data/mongodb:/data/db
  - /home/administrator/projects/data/mongodb/config:/data/configdb
```

Remove volume definitions:
```yaml
# Remove this section
volumes:
  mongodb_data:
  mongodb_config:
```

**Step 3: Restart container**
```bash
docker compose up -d
```

**Step 4: Verify**
```bash
docker ps | grep mongodb

# Test connection
docker exec mongodb mongosh --eval "db.version()"

# List databases
docker exec mongodb mongosh --eval "db.adminCommand('listDatabases')"

# Check data locations
docker inspect mongodb --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' | grep /data
```

**Step 5: Remove old volumes**
```bash
docker volume rm mongodb_data
docker volume rm mongodb_config
```

---

## Verification Checklist

After migrating each database:

- [ ] Container is running (`docker ps`)
- [ ] Can connect to database
- [ ] Data is accessible (databases/keys/collections exist)
- [ ] New mount point is correct (`docker inspect`)
- [ ] Applications using the database still work
- [ ] Backup script includes this data (`ls projects/data/{db}/`)

## Rollback Procedure

If migration fails, you can rollback:

```bash
# Stop container
docker stop <container-name>

# Restore docker-compose.yml to use volume
# (change back to volume mount)

# Start container (will use original volume with data intact)
docker compose up -d
```

The original Docker volume data is never deleted during migration, only copied. Safety backups are also created in `/home/administrator/projects/data/volume-backups/`.

## Post-Migration

### 1. Verify Backup Coverage

```bash
# Check all databases are in projects/data/
ls -lh /home/administrator/projects/data/

# Should show:
# postgres/
# timescaledb/
# redis/
# mongodb/
# qdrant/
# arangodb/
```

### 2. Test Backup Script

```bash
# Run backup to ensure everything is captured
sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh
```

### 3. Update Documentation

Update CLAUDE.md files in each database project to reflect new storage location.

### 4. Clean Up Old Volumes

**Only after confirming everything works for at least 24 hours:**

```bash
# List volumes
docker volume ls

# Remove old database volumes
docker volume rm postgres_data
docker volume rm timescaledb_data
docker volume rm redis_data
docker volume rm mongodb_data
docker volume rm mongodb_config
```

### 5. Remove Safety Backups

**Only after confirming stable operation for 1 week:**

```bash
# These are the tar.gz backups created during migration
rm -rf /home/administrator/projects/data/volume-backups/
```

## Troubleshooting

### Container won't start after migration

**Check logs:**
```bash
docker logs <container-name>
```

**Common issues:**
1. **Permission denied** - Run: `sudo chown -R administrator:administrators /home/administrator/projects/data/{db}/`
2. **Path doesn't exist** - Verify data was copied: `ls -la /home/administrator/projects/data/{db}/`
3. **SELinux issues** - Add `:z` or `:Z` to mount in docker-compose (if using SELinux)

### Data appears missing

**Check mount point:**
```bash
docker inspect <container> --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
```

**Verify data exists:**
```bash
ls -lh /home/administrator/projects/data/{database}/
```

### Performance issues

If using HDD, ensure `projects/data/` is on fast storage. Consider:
1. Moving to SSD
2. Using different mount options in docker-compose
3. Tuning database parameters for bind mounts vs volumes

## Expected Disk Usage

Based on current volumes:

```bash
# Check before migration
docker system df -v | grep -E "postgres|timescale|redis|mongo"
```

After migration, `projects/data/` will grow by approximately the same amount (plus safety backups temporarily).

## Benefits After Migration

✅ **Consistency** - All databases in one location
✅ **Easier backups** - Single tar archive
✅ **Better visibility** - `du -sh projects/data/*` shows all database sizes
✅ **Simpler migrations** - Copy entire data directory
✅ **Clearer ownership** - All files owned by administrator
✅ **Better disk management** - Can mount `/projects/data` on separate storage

---

**Status:** Ready for execution
**Risk Level:** Low (safety backups created, Docker volumes preserved)
**Recommended:** Migrate one database at a time during low-traffic periods
**Total Time:** 10-20 minutes for all databases
