#!/bin/bash
#
# healthcheck.sh - System and Docker Health Check Script
# Returns:
#   0       = No errors
#   1-99    = Fatal errors (count of fatal issues)
#   100+N   = Soft errors only (100 + count of soft issues, only if no fatal errors)
#
# Examples:
#   Exit 0   = Healthy
#   Exit 3   = 3 fatal errors
#   Exit 104 = 4 soft errors (no fatal)
#
# Usage:
#   ./healthcheck.sh           # Auto-detect mode (server/laptop)
#   ./healthcheck.sh -server   # Force server mode
#   ./healthcheck.sh -laptop   # Force laptop mode
#

set -uo pipefail

# Parse command-line arguments
MODE="auto"
if [ "${1:-}" = "-server" ]; then
    MODE="server"
elif [ "${1:-}" = "-laptop" ]; then
    MODE="laptop"
fi

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Counters
FATAL_COUNT=0
SOFT_COUNT=0

# Auto-detect mode if not explicitly set
if [ "$MODE" = "auto" ]; then
    # Check if critical infrastructure containers exist (indicates server)
    if command -v docker &> /dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE "^(traefik|keycloak|postgres)$"; then
            MODE="server"
        else
            MODE="laptop"
        fi
    else
        MODE="laptop"
    fi
fi

# Thresholds
DISK_WARN_THRESHOLD=80
DISK_FATAL_THRESHOLD=95
MEMORY_WARN_THRESHOLD=90
MEMORY_FATAL_THRESHOLD=95
LOAD_WARN_MULTIPLIER=2
LOAD_FATAL_MULTIPLIER=4

# Logging setup
LOG_DIR="$HOME/projects/data/logs/devscripts"
LOG_FILE="$LOG_DIR/healthcheck-$(date +%Y-%m-%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect all output to both console and log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "========================================"
echo "System Health Check - $(date)"
echo "========================================"
echo "Mode: $MODE"
echo "Hostname: $(hostname)"
echo "Log file: $LOG_FILE"
echo ""

#
# 1. DOCKER DAEMON CHECK (FATAL in server mode, SOFT in laptop mode)
#
echo "[CHECK] Docker daemon status..."
if ! systemctl is-active --quiet docker 2>/dev/null; then
    if [ "$MODE" = "server" ]; then
        echo -e "${RED}[FATAL]${NC} Docker daemon is not running"
        ((FATAL_COUNT++))
    else
        echo -e "${YELLOW}[WARN]${NC} Docker daemon is not running (optional in laptop mode)"
        ((SOFT_COUNT++))
    fi
else
    echo -e "${GREEN}[OK]${NC} Docker daemon is running"
fi
echo ""

#
# 2. DOCKER CONTAINER HEALTH CHECK
#
echo "[CHECK] Docker container health..."
if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    # Get all containers
    TOTAL_CONTAINERS=$(docker ps -a --format '{{.Names}}' | wc -l)
    RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}' | wc -l)

    echo "Total containers: $TOTAL_CONTAINERS"
    echo "Running containers: $RUNNING_CONTAINERS"

    # Check for unhealthy containers
    UNHEALTHY=$(docker ps --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null || true)
    if [ -n "$UNHEALTHY" ]; then
        UNHEALTHY_COUNT=$(echo "$UNHEALTHY" | wc -l)
        echo -e "${RED}[FATAL]${NC} Unhealthy containers detected:"
        while IFS= read -r container; do
            echo "  - $container"
        done <<< "$UNHEALTHY"
        FATAL_COUNT=$((FATAL_COUNT + UNHEALTHY_COUNT))
    fi

    # Check for exited containers (soft error - they might be intentionally stopped)
    EXITED=$(docker ps -a --filter "status=exited" --format '{{.Names}}' 2>/dev/null || true)
    if [ -n "$EXITED" ]; then
        EXITED_COUNT=$(echo "$EXITED" | wc -l)
        echo -e "${YELLOW}[WARN]${NC} $EXITED_COUNT exited container(s):"
        echo "$EXITED" | head -n 5
        if [ "$EXITED_COUNT" -gt 5 ]; then
            echo "  ... and $((EXITED_COUNT - 5)) more"
        fi
        SOFT_COUNT=$((SOFT_COUNT + 1))
    fi

    # Check for restarting containers (fatal)
    RESTARTING=$(docker ps --filter "status=restarting" --format '{{.Names}}' 2>/dev/null || true)
    if [ -n "$RESTARTING" ]; then
        RESTARTING_COUNT=$(echo "$RESTARTING" | wc -l)
        echo -e "${RED}[FATAL]${NC} Containers stuck restarting:"
        while IFS= read -r container; do
            echo "  - $container"
        done <<< "$RESTARTING"
        FATAL_COUNT=$((FATAL_COUNT + RESTARTING_COUNT))
    fi

    # Check for containers with high restart counts (soft error)
    HIGH_RESTART=$(docker ps --format '{{.Names}}\t{{.Status}}' | grep -E "Restarting \([5-9]|[1-9][0-9]+\)" || true)
    if [ -n "$HIGH_RESTART" ]; then
        HIGH_RESTART_COUNT=$(echo "$HIGH_RESTART" | wc -l)
        echo -e "${YELLOW}[WARN]${NC} Containers with high restart counts:"
        while IFS= read -r line; do
            echo "  - $line"
        done <<< "$HIGH_RESTART"
        SOFT_COUNT=$((SOFT_COUNT + 1))
    fi

    # Check critical infrastructure containers (fatal if not running) - SERVER MODE ONLY
    if [ "$MODE" = "server" ]; then
        CRITICAL_CONTAINERS=("traefik" "keycloak" "postgres" "loki" "grafana")
        for container in "${CRITICAL_CONTAINERS[@]}"; do
            if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                echo -e "${RED}[FATAL]${NC} Critical container not running: $container"
                ((FATAL_COUNT++))
            fi
        done
    fi

    if [ $FATAL_COUNT -eq 0 ] && [ $SOFT_COUNT -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} All containers healthy"
    fi
fi
echo ""

#
# 3. DISK SPACE CHECK
#
echo "[CHECK] Disk space usage..."
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
echo "Root partition: ${DISK_USAGE}% used"

if [ "$DISK_USAGE" -ge "$DISK_FATAL_THRESHOLD" ]; then
    echo -e "${RED}[FATAL]${NC} Disk usage critical (>=${DISK_FATAL_THRESHOLD}%)"
    ((FATAL_COUNT++))
elif [ "$DISK_USAGE" -ge "$DISK_WARN_THRESHOLD" ]; then
    echo -e "${YELLOW}[WARN]${NC} Disk usage high (>=${DISK_WARN_THRESHOLD}%)"
    ((SOFT_COUNT++))
else
    echo -e "${GREEN}[OK]${NC} Disk space healthy"
fi

# Check Docker volume space
if command -v docker &> /dev/null; then
    DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
    DOCKER_DISK=$(df "$DOCKER_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "Docker storage: ${DOCKER_DISK}% used"

    if [ "$DOCKER_DISK" -ge "$DISK_FATAL_THRESHOLD" ]; then
        echo -e "${RED}[FATAL]${NC} Docker storage critical (>=${DISK_FATAL_THRESHOLD}%)"
        ((FATAL_COUNT++))
    elif [ "$DOCKER_DISK" -ge "$DISK_WARN_THRESHOLD" ]; then
        echo -e "${YELLOW}[WARN]${NC} Docker storage high (>=${DISK_WARN_THRESHOLD}%)"
        ((SOFT_COUNT++))
    fi
fi
echo ""

#
# 4. MEMORY CHECK
#
echo "[CHECK] Memory usage..."
MEMORY_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
echo "Memory: ${MEMORY_USAGE}% used"

if [ "$MEMORY_USAGE" -ge "$MEMORY_FATAL_THRESHOLD" ]; then
    echo -e "${RED}[FATAL]${NC} Memory usage critical (>=${MEMORY_FATAL_THRESHOLD}%)"
    ((FATAL_COUNT++))
elif [ "$MEMORY_USAGE" -ge "$MEMORY_WARN_THRESHOLD" ]; then
    echo -e "${YELLOW}[WARN]${NC} Memory usage high (>=${MEMORY_WARN_THRESHOLD}%)"
    ((SOFT_COUNT++))
else
    echo -e "${GREEN}[OK]${NC} Memory usage healthy"
fi
echo ""

#
# 5. CPU LOAD CHECK
#
echo "[CHECK] CPU load average..."
CPU_CORES=$(nproc)
LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
LOAD_THRESHOLD_WARN=$(echo "$CPU_CORES * $LOAD_WARN_MULTIPLIER" | bc)
LOAD_THRESHOLD_FATAL=$(echo "$CPU_CORES * $LOAD_FATAL_MULTIPLIER" | bc)

echo "1-min load: $LOAD_1MIN (cores: $CPU_CORES)"
echo "Thresholds: warn=${LOAD_THRESHOLD_WARN}, fatal=${LOAD_THRESHOLD_FATAL}"

if (( $(echo "$LOAD_1MIN >= $LOAD_THRESHOLD_FATAL" | bc -l) )); then
    echo -e "${RED}[FATAL]${NC} Load average critical"
    ((FATAL_COUNT++))
elif (( $(echo "$LOAD_1MIN >= $LOAD_THRESHOLD_WARN" | bc -l) )); then
    echo -e "${YELLOW}[WARN]${NC} Load average high"
    ((SOFT_COUNT++))
else
    echo -e "${GREEN}[OK]${NC} Load average healthy"
fi
echo ""

#
# 6. NETWORK CONNECTIVITY CHECK
#
echo "[CHECK] Network connectivity..."

# Check if we can reach the internet (soft error if not)
if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Cannot reach internet (8.8.8.8)"
    ((SOFT_COUNT++))
else
    echo -e "${GREEN}[OK]${NC} Internet connectivity"
fi

# Check critical Docker networks exist (fatal if missing) - SERVER MODE ONLY
if [ "$MODE" = "server" ] && command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    CRITICAL_NETWORKS=("traefik-net" "postgres-net" "keycloak-net")
    NETWORK_FAIL=0
    for network in "${CRITICAL_NETWORKS[@]}"; do
        if ! docker network ls --format '{{.Name}}' | grep -q "^${network}$"; then
            echo -e "${RED}[FATAL]${NC} Critical Docker network missing: $network"
            ((FATAL_COUNT++))
            NETWORK_FAIL=1
        fi
    done
    if [ $NETWORK_FAIL -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} Critical Docker networks exist"
    fi
fi
echo ""

#
# 7. LAPTOP-SPECIFIC CHECKS
#
if [ "$MODE" = "laptop" ]; then
    #
    # 7a. WiFi STATUS AND QUALITY CHECK
    #
    echo "[CHECK] WiFi status and quality..."

    # Find wireless interface
    WIFI_INTERFACE=$(ip link | grep -o 'wl[^:]*' | head -1)

    if [ -n "$WIFI_INTERFACE" ]; then
        # Check if interface is up
        if ip link show "$WIFI_INTERFACE" | grep -q "state UP"; then
            echo -e "${GREEN}[OK]${NC} WiFi interface $WIFI_INTERFACE is up"

            # Get connection details if available
            if command -v iwconfig &> /dev/null; then
                SSID=$(iwconfig "$WIFI_INTERFACE" 2>/dev/null | grep ESSID | sed 's/.*ESSID:"\(.*\)".*/\1/')
                SIGNAL=$(iwconfig "$WIFI_INTERFACE" 2>/dev/null | grep "Signal level" | sed 's/.*Signal level=\(.*\) dBm.*/\1/')

                if [ -n "$SSID" ] && [ "$SSID" != "off/any" ]; then
                    echo "  Connected to: $SSID"
                    if [ -n "$SIGNAL" ]; then
                        echo "  Signal strength: ${SIGNAL} dBm"
                        # Warn if signal is weak (below -70 dBm)
                        if [ "$SIGNAL" -lt -70 ]; then
                            echo -e "${YELLOW}[WARN]${NC} Weak WiFi signal (${SIGNAL} dBm)"
                            ((SOFT_COUNT++))
                        fi
                    fi
                fi
            fi

            # Check for recent disconnects in journal
            RECENT_DISCONNECTS=$(journalctl --no-pager -b --since "1 hour ago" 2>/dev/null | grep -i "$WIFI_INTERFACE.*disconnect" | wc -l)
            if [ "$RECENT_DISCONNECTS" -gt 3 ]; then
                echo -e "${YELLOW}[WARN]${NC} $RECENT_DISCONNECTS WiFi disconnects in last hour"
                ((SOFT_COUNT++))
            fi
        else
            echo -e "${YELLOW}[WARN]${NC} WiFi interface $WIFI_INTERFACE is down"
            ((SOFT_COUNT++))
        fi
    else
        echo "No wireless interface detected (might be wired connection)"
    fi
    echo ""

    #
    # 7b. BATTERY STATUS CHECK
    #
    echo "[CHECK] Battery status..."

    # Check for battery using upower or /sys/class/power_supply
    if command -v upower &> /dev/null; then
        BATTERY_PATH=$(upower -e | grep battery | head -1)
        if [ -n "$BATTERY_PATH" ]; then
            BATTERY_PERCENT=$(upower -i "$BATTERY_PATH" | grep percentage | awk '{print $2}' | sed 's/%//')
            BATTERY_STATE=$(upower -i "$BATTERY_PATH" | grep state | awk '{print $2}')
            BATTERY_HEALTH=$(upower -i "$BATTERY_PATH" | grep capacity | awk '{print $2}' | sed 's/%//')

            echo "Battery: ${BATTERY_PERCENT}% ($BATTERY_STATE)"

            if [ -n "$BATTERY_HEALTH" ]; then
                echo "Battery health: ${BATTERY_HEALTH}%"
                if [ "$BATTERY_HEALTH" -lt 70 ]; then
                    echo -e "${YELLOW}[WARN]${NC} Battery health degraded (${BATTERY_HEALTH}%)"
                    ((SOFT_COUNT++))
                fi
            fi

            # Warn if battery is low and discharging
            if [ "$BATTERY_STATE" = "discharging" ] && [ "$BATTERY_PERCENT" -lt 20 ]; then
                echo -e "${YELLOW}[WARN]${NC} Battery low (${BATTERY_PERCENT}%) and discharging"
                ((SOFT_COUNT++))
            elif [ "$BATTERY_STATE" = "discharging" ] && [ "$BATTERY_PERCENT" -lt 10 ]; then
                echo -e "${RED}[FATAL]${NC} Battery critical (${BATTERY_PERCENT}%)"
                ((FATAL_COUNT++))
            else
                echo -e "${GREEN}[OK]${NC} Battery status healthy"
            fi
        else
            echo "No battery detected (desktop or AC-only)"
        fi
    elif [ -d "/sys/class/power_supply/BAT0" ]; then
        BATTERY_PERCENT=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "unknown")
        BATTERY_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "unknown")

        echo "Battery: ${BATTERY_PERCENT}% ($BATTERY_STATUS)"

        if [ "$BATTERY_STATUS" = "Discharging" ] && [ "$BATTERY_PERCENT" != "unknown" ] && [ "$BATTERY_PERCENT" -lt 20 ]; then
            echo -e "${YELLOW}[WARN]${NC} Battery low (${BATTERY_PERCENT}%) and discharging"
            ((SOFT_COUNT++))
        else
            echo -e "${GREEN}[OK]${NC} Battery status healthy"
        fi
    else
        echo "No battery detected (desktop or AC-only)"
    fi
    echo ""

    #
    # 7c. SYSTEM JOURNAL ERROR SCAN (LAPTOP)
    #
    echo "[CHECK] System journal errors (last 24 hours)..."

    # Scan journal for network, hardware, and driver errors
    if command -v journalctl &> /dev/null; then
        TEMP_JOURNAL_ERRORS=$(mktemp)
        trap "rm -f $TEMP_JOURNAL_ERRORS" EXIT

        # Collect errors from last 24 hours
        journalctl --no-pager -p err -b --since "24 hours ago" 2>/dev/null | \
            grep -iE "(network|wifi|ethernet|firmware|driver|usb|hardware|nvme|disk|thermal)" | \
            grep -viE "(audit|apparmor|segfault)" | \
            tail -20 > "$TEMP_JOURNAL_ERRORS"

        if [ -s "$TEMP_JOURNAL_ERRORS" ]; then
            ERROR_COUNT=$(wc -l < "$TEMP_JOURNAL_ERRORS")
            echo -e "${YELLOW}[WARN]${NC} Found $ERROR_COUNT hardware/network error(s) in journal:"
            echo ""
            head -10 "$TEMP_JOURNAL_ERRORS" | while read -r line; do
                # Truncate long lines
                TRUNCATED=$(echo "$line" | cut -c1-120)
                echo "  $TRUNCATED"
            done
            if [ "$ERROR_COUNT" -gt 10 ]; then
                echo "  ... and $((ERROR_COUNT - 10)) more errors"
            fi
            echo ""
            echo "  Run 'journalctl -p err -b --since \"24 hours ago\"' for full details"
            ((SOFT_COUNT++))
        else
            echo -e "${GREEN}[OK]${NC} No hardware/network errors in journal"
        fi
    else
        echo -e "${YELLOW}[WARN]${NC} journalctl not available"
    fi
    echo ""
fi

#
# 8. SYSTEM UPTIME
#
echo "[CHECK] System uptime..."
UPTIME_DAYS=$(uptime | awk '{print $3}' | sed 's/,//')
echo "Uptime: $(uptime -p)"
echo -e "${GREEN}[OK]${NC} System uptime check complete"
echo ""

#
# 9. DOCKER SYSTEM RESOURCE CHECK
#
if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    echo "[CHECK] Docker system resources..."

    # Check for dangling images (soft warning)
    DANGLING_IMAGES=$(docker images -f "dangling=true" -q | wc -l)
    if [ "$DANGLING_IMAGES" -gt 10 ]; then
        echo -e "${YELLOW}[WARN]${NC} $DANGLING_IMAGES dangling images (consider docker image prune)"
        ((SOFT_COUNT++))
    else
        echo -e "${GREEN}[OK]${NC} Dangling images: $DANGLING_IMAGES"
    fi

    # Check for unused volumes (soft warning)
    UNUSED_VOLUMES=$(docker volume ls -qf dangling=true | wc -l)
    if [ "$UNUSED_VOLUMES" -gt 5 ]; then
        echo -e "${YELLOW}[WARN]${NC} $UNUSED_VOLUMES unused volumes (consider docker volume prune)"
        ((SOFT_COUNT++))
    else
        echo -e "${GREEN}[OK]${NC} Unused volumes: $UNUSED_VOLUMES"
    fi
fi
echo ""

#
# 10. CONTAINER LOG ERROR ANALYSIS
#
echo "[CHECK] Recent container log errors..."

if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    # Create temporary file for error collection
    TEMP_ERRORS=$(mktemp)
    trap "rm -f $TEMP_ERRORS" EXIT

    # Check logs from running containers (last hour)
    RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}')

    if [ -n "$RUNNING_CONTAINERS" ]; then
        # Collect errors from all containers
        while IFS= read -r container; do
            # Get recent errors, exclude known benign patterns
            docker logs "$container" --since 1h 2>&1 | \
                grep -iE "error|fatal|critical|exception" | \
                grep -viE "terminating connection due to administrator command|received fast shutdown request|background worker.*exited|shutting down|checkpoint starting: shutdown|database system is shut down|database system was shut down|connection reset by peer|broken pipe|client disconnected|handshake failure|tls.*handshake|eof.*error|timeout.*error|dial tcp.*timeout|temporary failure|context canceled" | \
                sed "s/^/[$container] /" >> "$TEMP_ERRORS" 2>/dev/null || true
        done <<< "$RUNNING_CONTAINERS"

        # Analyze collected errors
        if [ -s "$TEMP_ERRORS" ]; then
            # Group and count similar errors
            ERROR_SUMMARY=$(sort "$TEMP_ERRORS" | uniq -c | sort -rn)

            # Count unique error patterns
            UNIQUE_ERRORS=$(echo "$ERROR_SUMMARY" | wc -l)

            # Count recurring errors (appearing 3+ times - indicates ongoing issue)
            RECURRING_ERRORS=$(echo "$ERROR_SUMMARY" | awk '$1 >= 3' | wc -l)

            if [ "$RECURRING_ERRORS" -gt 0 ]; then
                echo -e "${YELLOW}[WARN]${NC} $RECURRING_ERRORS recurring error pattern(s) detected (3+ occurrences):"
                echo ""

                # Show top 5 recurring error patterns
                echo "$ERROR_SUMMARY" | awk '$1 >= 3' | head -5 | while read -r count error; do
                    # Truncate long error messages
                    ERROR_MSG=$(echo "$error" | cut -c1-100)
                    echo "  ($count occurrences) $ERROR_MSG"
                done

                if [ "$RECURRING_ERRORS" -gt 5 ]; then
                    echo "  ... and $((RECURRING_ERRORS - 5)) more error patterns"
                fi
                echo ""
                echo "  Run 'docker logs <container>' for details"

                SOFT_COUNT=$((SOFT_COUNT + 1))
            else
                echo -e "${GREEN}[OK]${NC} No recurring errors found (checked last hour)"
            fi
        else
            echo -e "${GREEN}[OK]${NC} No errors found in recent container logs"
        fi
    else
        echo -e "${YELLOW}[WARN]${NC} No running containers to check"
    fi
else
    echo -e "${YELLOW}[WARN]${NC} Cannot check logs - Docker not available"
fi
echo ""

#
# SUMMARY AND EXIT CODE
#
echo "========================================"
echo "Health Check Summary"
echo "========================================"
echo "Fatal errors: $FATAL_COUNT"
echo "Soft errors:  $SOFT_COUNT"
echo ""

if [ $FATAL_COUNT -gt 0 ]; then
    echo -e "${RED}Status: CRITICAL${NC}"
    echo "Exit code: $FATAL_COUNT (fatal errors)"
    FINAL_EXIT_CODE=$FATAL_COUNT
elif [ $SOFT_COUNT -gt 0 ]; then
    FINAL_EXIT_CODE=$((100 + SOFT_COUNT))
    echo -e "${YELLOW}Status: WARNING${NC}"
    echo "Exit code: $FINAL_EXIT_CODE (soft errors: $SOFT_COUNT)"
else
    echo -e "${GREEN}Status: HEALTHY${NC}"
    echo "Exit code: 0"
    FINAL_EXIT_CODE=0
fi

#
# CLEANUP OLD LOGS (90 days)
#
echo ""
echo "========================================"
echo "Log Maintenance"
echo "========================================"

# Find and remove log files older than 90 days
OLD_LOGS=$(find "$LOG_DIR" -name "healthcheck-*.log" -type f -mtime +90 2>/dev/null)
if [ -n "$OLD_LOGS" ]; then
    OLD_LOG_COUNT=$(echo "$OLD_LOGS" | wc -l)
    echo "Removing $OLD_LOG_COUNT log file(s) older than 90 days..."
    echo "$OLD_LOGS" | xargs rm -f
    echo -e "${GREEN}✓${NC} Old logs cleaned up"
else
    echo "No logs older than 90 days found"
fi

# Show current log file count
TOTAL_LOGS=$(find "$LOG_DIR" -name "healthcheck-*.log" -type f 2>/dev/null | wc -l)
echo "Total health check logs: $TOTAL_LOGS"
echo ""

exit $FINAL_EXIT_CODE
