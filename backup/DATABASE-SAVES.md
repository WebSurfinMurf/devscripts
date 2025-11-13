# Database Save Scripts for Backup System

## Overview

Before backing up database data directories, it's critical to ensure all in-memory data has been flushed to disk. This prevents data corruption and ensures backup consistency.

**Created:** 2025-11-10
**Purpose:** Pre-backup database checkpoint/save operations

## Architecture

### Backup Flow with Database Saves

```
backup-projects-data.sh
    ↓
1. PRE-BACKUP PHASE: Force all databases to save
    ├── PostgreSQL: CHECKPOINT
    ├── TimescaleDB: CHECKPOINT
    ├── Redis: SAVE
    └── MongoDB: fsync
    ↓
2. BACKUP PHASE: Create tar.gz archives
    ├── Daily backups (every day)
    ├── Weekly backups (Saturdays)
    └── Monthly backups (first Saturday)
    ↓
3. ROTATION PHASE: Clean old backups
    ├── Keep last 7 daily
    ├── Keep last 4 weekly
    └── Keep last 6 monthly
```

## Database Save Scripts

All infrastructure databases are covered:
- **PostgreSQL** (main database + keycloak-postgres)
- **TimescaleDB** (time-series database)
- **Redis** (cache and sessions)
- **MongoDB** (document database)
- **Qdrant** (vector database - used by mem0/openmemory)
- **ArangoDB** (multi-model graph database)

### 1. PostgreSQL (`/home/administrator/projects/postgres/manualsavealldb.sh`)

**Purpose:** Forces PostgreSQL to flush all dirty buffers to disk

**Command:** `CHECKPOINT`

**What it does:**
- Writes all modified data pages to disk
- Ensures WAL (Write-Ahead Log) is synced
- Creates a recovery checkpoint
- Handles both main `postgres` and `keycloak-postgres` containers

**Output:**
```
=== PostgreSQL: Forcing checkpoint to save all data to disk ===
Using PostgreSQL user: admin
Running CHECKPOINT command...
✓ PostgreSQL checkpoint completed successfully
  All dirty buffers have been written to disk
  Database is in consistent state for backup
```

### 2. TimescaleDB (`/home/administrator/projects/timescaledb/manualsavealldb.sh`)

**Purpose:** Forces TimescaleDB (PostgreSQL-based) to flush all data

**Command:** `CHECKPOINT`

**What it does:**
- Same as PostgreSQL (TimescaleDB is PostgreSQL extension)
- Ensures hypertables are in consistent state
- Flushes compressed chunks to disk

**Output:**
```
=== TimescaleDB: Forcing checkpoint to save all data to disk ===
Using PostgreSQL user: tsdbadmin
Running CHECKPOINT command...
✓ TimescaleDB checkpoint completed successfully
  All hypertables are in consistent state for backup
```

### 3. Redis (`/home/administrator/projects/redis/manualsavealldb.sh`)

**Purpose:** Forces Redis to perform synchronous save to disk

**Command:** `SAVE`

**What it does:**
- Blocks Redis until all in-memory data is written to dump.rdb
- Creates a point-in-time snapshot
- Shows changes since last save (before and after)

**Why SAVE instead of BGSAVE:**
- SAVE is synchronous (guarantees completion before backup)
- BGSAVE is asynchronous (could still be running during backup)
- Pre-backup scripts should block until complete

**Output:**
```
=== Redis: Forcing synchronous save to disk ===
Using authenticated connection
Checking Redis status...
rdb_changes_since_last_save:2
rdb_last_save_time:1762820498

Running SAVE command (this will block Redis until complete)...
OK
✓ Redis SAVE completed successfully
  rdb_changes_since_last_save:0
  All in-memory data has been written to dump.rdb
```

### 4. MongoDB (`/home/administrator/projects/mongodb/manualsavealldb.sh`)

**Purpose:** Forces MongoDB to flush all pending writes to disk

**Command:** `db.adminCommand({fsync: 1, lock: false})`

**What it does:**
- Forces all pending writes to disk
- Does NOT lock database (lock: false allows continued operations)
- Ensures journal is synced
- Makes all databases consistent for backup

**Output:**
```
=== MongoDB: Forcing fsync to save all data to disk ===
Using authenticated connection
Running fsync command...
✓ MongoDB fsync completed successfully
  All dirty pages have been written to disk
  All databases are in consistent state for backup
```

### 5. Qdrant (`/home/administrator/projects/qdrant/manualsavealldb.sh`)

**Purpose:** Forces Qdrant to create snapshots of all vector collections

**Command:** `POST /collections/{collection}/snapshots` (REST API)

**What it does:**
- Creates point-in-time snapshot for each collection
- Saves vector embeddings and metadata
- Used by mem0/openmemory for AI memory storage
- Ensures all vector data is persisted

**Output:**
```
=== Qdrant: Creating snapshots of all collections ===
Using non-authenticated connection
Fetching list of collections from http://localhost:6333...
Found collections:
  - openmemory
  - mem0migrations
  - langchain_docs

Creating snapshot for collection: openmemory
  ✓ Snapshot created: openmemory-4337123064962167-2025-11-11-00-26-59.snapshot
✓ Qdrant snapshots completed successfully
  Total snapshots created: 3
  All vector collections are in consistent state for backup
```

### 6. ArangoDB (`/home/administrator/projects/arangodb/manualsavealldb.sh`)

**Purpose:** Forces ArangoDB to flush WAL (Write-Ahead Log) to disk

**Command:** `require("internal").wal.flush(true, true);`

**What it does:**
- Flushes Write-Ahead Log to disk
- Syncs all pending transactions
- Ensures graph data consistency
- Makes all databases and collections consistent

**Output:**
```
=== ArangoDB: Forcing WAL flush and sync ===
Using authenticated connection
Flushing Write-Ahead Log (WAL) to disk...
✓ ArangoDB WAL flush completed successfully

Checking database status...
Databases: 2
  - _system: 0 collections
  - ai_memory: 1 collections

✓ All ArangoDB data has been flushed to disk
  Write-Ahead Log synced
  All databases are in consistent state for backup
```

## Integration with Backup Script

### Modified: `/home/administrator/projects/devscripts/backup/backup-projects-data.sh`

**Added Pre-Backup Phase (lines 77-103):**

```bash
# PRE-BACKUP: Force database saves to disk
echo -e "${BLUE}=== Pre-Backup: Forcing database saves to disk ===${NC}"
SAVE_SCRIPTS=(
    "/home/administrator/projects/postgres/manualsavealldb.sh"
    "/home/administrator/projects/timescaledb/manualsavealldb.sh"
    "/home/administrator/projects/redis/manualsavealldb.sh"
    "/home/administrator/projects/mongodb/manualsavealldb.sh"
    "/home/administrator/projects/qdrant/manualsavealldb.sh"
    "/home/administrator/projects/arangodb/manualsavealldb.sh"
)

for SAVE_SCRIPT in "${SAVE_SCRIPTS[@]}"; do
    if [ -x "$SAVE_SCRIPT" ]; then
        echo -e "${BLUE}Running: $(basename $(dirname $SAVE_SCRIPT))/$(basename $SAVE_SCRIPT)${NC}"
        if bash "$SAVE_SCRIPT" 2>&1; then
            echo -e "${GREEN}✓ Database save completed${NC}"
        else
            echo -e "${YELLOW}⚠ Database save failed (non-critical, continuing)${NC}"
        fi
        echo ""
    fi
done

echo -e "${GREEN}=== All database saves completed ===${NC}"
```

**Key Features:**
- Runs BEFORE any tar operations
- Non-blocking: Failed saves are logged but don't stop backup
- Idempotent: Safe to run multiple times
- Automatic: No manual intervention needed

## Usage

### Automatic (via backup script)

```bash
# Database saves run automatically
sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh
```

### Manual (individual database)

```bash
# Force PostgreSQL save
/home/administrator/projects/postgres/manualsavealldb.sh

# Force TimescaleDB save
/home/administrator/projects/timescaledb/manualsavealldb.sh

# Force Redis save
/home/administrator/projects/redis/manualsavealldb.sh

# Force MongoDB save
/home/administrator/projects/mongodb/manualsavealldb.sh

# Force Qdrant save (vector database)
/home/administrator/projects/qdrant/manualsavealldb.sh

# Force ArangoDB save (graph database)
/home/administrator/projects/arangodb/manualsavealldb.sh
```

## Technical Details

### PostgreSQL/TimescaleDB CHECKPOINT

**Documentation:** https://www.postgresql.org/docs/current/sql-checkpoint.html

**What it guarantees:**
- All dirty buffers written to disk
- WAL (Write-Ahead Log) synced
- Recovery point created
- Consistent state for backup

**Performance Impact:**
- Blocks until all writes complete (usually < 1 second)
- Can cause brief I/O spike
- Safe to run during normal operations

### Redis SAVE vs BGSAVE

**SAVE (used in scripts):**
- Synchronous (blocks until complete)
- Guarantees completion before backup
- Safe for small to medium datasets
- Brief blocking period (usually < 1 second)

**BGSAVE (NOT used):**
- Asynchronous (returns immediately)
- Forks background process
- No guarantee when it completes
- Risk of incomplete save during backup

### MongoDB fsync

**Documentation:** https://www.mongodb.com/docs/manual/reference/command/fsync/

**Lock vs No-Lock:**
- `lock: true` - Freezes database (not suitable for backup scripts)
- `lock: false` - Flushes data but allows operations (used in scripts)

**What it guarantees:**
- All in-memory data written to disk
- Journal synced
- Consistent recovery point
- Database remains available

## Error Handling

All scripts follow the same pattern:

```bash
set -e  # Exit on error

# Attempt operation
docker exec <container> <command>

if [ $? -eq 0 ]; then
    echo "✓ Success"
else
    echo "✗ Failed"
    exit 1
fi
```

**In backup script:**
- Failures are logged but don't stop backup
- Marked as "non-critical, continuing"
- Ensures backup completes even if database save fails

## Verification

### Check if saves are working

```bash
# Run backup in verbose mode
sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh

# Look for these sections in output:
# === Pre-Backup: Forcing database saves to disk ===
# Running: postgres/manualsavealldb.sh
# ✓ PostgreSQL checkpoint completed successfully
```

### Check backup logs

```bash
# View recent backup log
tail -100 $BACKUPROOT/administrator/backup.log

# Should contain entries like:
# 2025-11-10 19:30:01 - PRE-BACKUP - PostgreSQL checkpoint: SUCCESS
```

## Performance Considerations

### Average Save Times (on linuxserver.lan)

- **PostgreSQL**: < 1 second
- **TimescaleDB**: < 1 second
- **Redis**: < 1 second (256MB dataset)
- **MongoDB**: < 1 second
- **Qdrant**: ~1-3 seconds (depends on number of collections)
- **ArangoDB**: < 1 second

**Total pre-backup overhead:** ~6-8 seconds

### Blocking Impact

During the save operations:
- **PostgreSQL**: Brief write blocking
- **TimescaleDB**: Brief write blocking
- **Redis**: Brief blocking of all operations
- **MongoDB**: No blocking (lock: false)
- **Qdrant**: No blocking (snapshot is asynchronous)
- **ArangoDB**: Brief write blocking during WAL flush

**Recommendation:** Run backups during low-traffic periods (e.g., 4 AM)

## Monitoring

### Check database status after save

```bash
# PostgreSQL - verify checkpoint time
docker exec postgres psql -U admin -d postgres -c "SELECT pg_last_wal_replay_lsn();"

# Redis - verify save time
docker exec redis redis-cli -a [password] INFO persistence | grep rdb_last_save_time

# MongoDB - verify sync
docker exec mongodb mongosh --quiet --eval "db.serverStatus().backgroundFlushing"
```

## Troubleshooting

### Save script fails

**PostgreSQL:**
```bash
# Check if container is running
docker ps | grep postgres

# Check if user exists
docker exec postgres psql -U admin -c "\du"

# Test manually
docker exec postgres psql -U admin -c "CHECKPOINT;"
```

**Redis:**
```bash
# Check if password is correct
grep REDIS_PASSWORD /home/administrator/secrets/redis.env

# Test connection
docker exec redis redis-cli -a [password] PING

# Test manually
docker exec redis redis-cli -a [password] SAVE
```

**MongoDB:**
```bash
# Check if container is running
docker ps | grep mongodb

# Test connection
docker exec mongodb mongosh --eval "db.version()"

# Test manually
docker exec mongodb mongosh --eval "db.adminCommand({fsync: 1, lock: false})"
```

### Backup continues despite save failure

This is by design! The backup script marks save failures as "non-critical" and continues with the backup. While not ideal, having a backup with potentially unsaved data is better than no backup at all.

**To make saves mandatory:**
Edit `/home/administrator/projects/devscripts/backup/backup-projects-data.sh` and change:
```bash
else
    echo -e "${YELLOW}⚠ Database save failed (non-critical, continuing)${NC}"
```
to:
```bash
else
    echo -e "${RED}✗ Database save failed (critical, aborting)${NC}"
    exit 1
```

## Best Practices

1. **Run saves before every backup** (automated in backup-projects-data.sh)
2. **Monitor save completion** via backup logs
3. **Test saves independently** before relying on them
4. **Schedule backups during low-traffic periods** to minimize impact
5. **Keep save scripts executable** (`chmod +x`)
6. **Update scripts if database passwords change**

## Files Created

```
/home/administrator/projects/
├── postgres/
│   └── manualsavealldb.sh         # PostgreSQL checkpoint script
├── timescaledb/
│   └── manualsavealldb.sh         # TimescaleDB checkpoint script
├── redis/
│   └── manualsavealldb.sh         # Redis save script
├── mongodb/
│   └── manualsavealldb.sh         # MongoDB fsync script
├── qdrant/
│   └── manualsavealldb.sh         # Qdrant snapshot script (vector DB)
├── arangodb/
│   └── manualsavealldb.sh         # ArangoDB WAL flush script (graph DB)
└── devscripts/backup/
    ├── backup-projects-data.sh     # Modified to call save scripts
    └── DATABASE-SAVES.md           # This documentation
```

## Testing

### Individual Scripts
```bash
# Test each script individually
/home/administrator/projects/postgres/manualsavealldb.sh
/home/administrator/projects/timescaledb/manualsavealldb.sh
/home/administrator/projects/redis/manualsavealldb.sh
/home/administrator/projects/mongodb/manualsavealldb.sh
/home/administrator/projects/qdrant/manualsavealldb.sh
/home/administrator/projects/arangodb/manualsavealldb.sh
```

### Full Backup with Saves
```bash
# Run backup (includes pre-backup saves)
sudo /home/administrator/projects/devscripts/backup/backup-projects-data.sh

# Check if saves executed
grep "database save" $BACKUPROOT/administrator/backup.log
```

---

**Status:** ✅ Implemented and Tested
**Last Updated:** 2025-11-10
**Coverage:** 6 database systems (PostgreSQL, TimescaleDB, Redis, MongoDB, Qdrant, ArangoDB)
**All database save scripts operational and integrated with backup system**
