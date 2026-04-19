#!/bin/bash
# Raise inotify limits for container host (78+ containers + dev tooling)
# Fixes: "Failed to allocate directory watch: Too many open files"
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Re-running with sudo..."
    exec sudo "$0" "$@"
fi

CONF=/etc/sysctl.d/60-inotify.conf

echo "[INFO] Writing $CONF"
cat > "$CONF" <<'EOF'
# Raised for container host (78+ containers, dev tooling)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
fs.inotify.max_queued_events = 32768
EOF

echo "[INFO] Applying sysctl settings"
sysctl -p "$CONF"

echo ""
echo "[SUCCESS] Applied. Current values:"
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances fs.inotify.max_queued_events
