#!/bin/bash
#
# PiSignage Log Rotation - compatibility wrapper
#
# Rotation is now handled by the standard logrotate config installed at
# /etc/logrotate.d/pisignage (see setup-log-rotation-cron.sh), driven by a
# systemd timer (pisignage-logrotate.timer). This script is kept only as a
# compatibility entry point so the web UI (web/api/logs.php) and any existing
# callers can still trigger an immediate rotation.
#
# It simply forces a logrotate run against the PiSignage config. If logrotate
# or the config is unavailable, it falls back to a minimal in-place rotation so
# the manual "Rotation & Nettoyage" button never hard-fails.
#
# Usage: ./rotate-logs.sh [--force]
#

set -e

LOGS_DIR="/opt/pisignage/logs"
LOGROTATE_CONF="/etc/logrotate.d/pisignage"
LOGROTATE_STATE="/var/lib/logrotate/pisignage.status"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Manual triggers always force rotation regardless of size thresholds.
FORCE_FLAG="--force"

log_info "Starting PiSignage log rotation (logrotate wrapper)..."

if command -v logrotate >/dev/null 2>&1 && [ -f "$LOGROTATE_CONF" ]; then
    log_info "Using logrotate config: $LOGROTATE_CONF"
    if logrotate $FORCE_FLAG --state "$LOGROTATE_STATE" "$LOGROTATE_CONF"; then
        log_info "logrotate completed successfully"
    else
        log_warn "logrotate returned non-zero; some logs may not have rotated"
    fi
else
    # Fallback: minimal in-place rotation when logrotate/config is missing.
    log_warn "logrotate or $LOGROTATE_CONF unavailable - using built-in fallback"
    for logfile in "$LOGS_DIR"/*.log; do
        [ -f "$logfile" ] || continue
        filename=$(basename "$logfile")
        # Skip youtube download logs (short-lived, cleaned by age elsewhere)
        case "$filename" in
            youtube_*) continue ;;
        esac
        size_mb=$(du -m "$logfile" | cut -f1)
        if [ "$size_mb" -gt 10 ]; then
            rotated="${logfile}.$(date +%Y%m%d-%H%M%S)"
            mv "$logfile" "$rotated"
            touch "$logfile"
            chown www-data:www-data "$logfile" 2>/dev/null || true
            gzip "$rotated" 2>/dev/null || true
            log_info "Rotated $filename (${size_mb}MB) -> $(basename "$rotated").gz"
        fi
    done
fi

# Log this rotation event for the audit trail (also surfaced in the logs UI).
mkdir -p "$LOGS_DIR" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Log rotation triggered (logrotate wrapper)" >> "$LOGS_DIR/system.log" 2>/dev/null || true

log_info "Rotation completed."
exit 0
