#!/bin/bash
#
# PiSignage Log Rotation and Cleanup Script
# Runs daily to keep log sizes manageable
#
# Usage: ./rotate-logs.sh [--force]
#

set -e

LOGS_DIR="/opt/pisignage/logs"
MAX_LOG_SIZE_MB=10
MAX_AGE_DAYS=7
NGINX_MAX_SIZE_MB=50

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

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ] && [ -z "$SUDO_USER" ]; then
    log_warn "This script should be run with sudo for Nginx log rotation"
fi

log_info "Starting PiSignage log rotation..."

# 1. Rotate large PiSignage logs
log_info "Checking PiSignage logs..."

for logfile in "$LOGS_DIR"/*.log; do
    if [ -f "$logfile" ]; then
        filename=$(basename "$logfile")

        # Skip youtube download logs (handled separately)
        if [[ "$filename" == youtube_* ]]; then
            continue
        fi

        size_mb=$(du -m "$logfile" | cut -f1)

        if [ "$size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
            log_warn "$filename is ${size_mb}MB (> ${MAX_LOG_SIZE_MB}MB) - rotating..."

            # Create rotated filename with timestamp
            rotated="${logfile}.$(date +%Y%m%d-%H%M%S)"

            # Rotate and compress
            mv "$logfile" "$rotated"
            touch "$logfile"
            chown www-data:www-data "$logfile"
            gzip "$rotated"

            log_info "Rotated to $(basename "$rotated").gz"
        else
            log_info "$filename: ${size_mb}MB (OK)"
        fi
    fi
done

# 2. Clean old YouTube download logs (>7 days)
log_info "Cleaning old YouTube download logs (>${MAX_AGE_DAYS} days)..."

youtube_deleted=0
for logfile in "$LOGS_DIR"/youtube_*.log; do
    if [ -f "$logfile" ]; then
        age_days=$(( ($(date +%s) - $(stat -c %Y "$logfile")) / 86400 ))

        if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
            log_warn "Deleting $(basename "$logfile") (${age_days} days old)"
            rm -f "$logfile"
            ((youtube_deleted++))
        fi
    fi
done

log_info "Deleted $youtube_deleted old YouTube logs"

# 3. Clean old rotated logs (>30 days)
log_info "Cleaning old rotated logs (>30 days)..."

rotated_deleted=0
for logfile in "$LOGS_DIR"/*.log.*; do
    if [ -f "$logfile" ]; then
        age_days=$(( ($(date +%s) - $(stat -c %Y "$logfile")) / 86400 ))

        if [ "$age_days" -gt 30 ]; then
            log_warn "Deleting $(basename "$logfile") (${age_days} days old)"
            rm -f "$logfile"
            ((rotated_deleted++))
        fi
    fi
done

log_info "Deleted $rotated_deleted old rotated logs"

# 4. Rotate Nginx logs if too large
log_info "Checking Nginx logs..."

nginx_access="/var/log/nginx/access.log"
nginx_error="/var/log/nginx/error.log"

if [ -f "$nginx_access" ]; then
    size_mb=$(du -m "$nginx_access" | cut -f1)

    if [ "$size_mb" -gt "$NGINX_MAX_SIZE_MB" ]; then
        log_warn "Nginx access.log is ${size_mb}MB (> ${NGINX_MAX_SIZE_MB}MB) - rotating..."

        # Use logrotate-like approach
        if [ -f "${nginx_access}.1" ]; then
            mv "${nginx_access}.1" "${nginx_access}.2"
        fi

        cp "$nginx_access" "${nginx_access}.1"
        truncate -s 0 "$nginx_access"

        # Compress old log
        gzip -f "${nginx_access}.1" 2>/dev/null || true

        # Reload nginx to reopen log files
        if command -v systemctl &> /dev/null; then
            systemctl reload nginx 2>/dev/null || true
        fi

        log_info "Nginx access log rotated and truncated"
    else
        log_info "Nginx access.log: ${size_mb}MB (OK)"
    fi
fi

# 5. Clean very old Nginx rotated logs (>14 days)
log_info "Cleaning old Nginx rotated logs (>14 days)..."

nginx_deleted=0
for logfile in /var/log/nginx/*.log.[0-9]* /var/log/nginx/*.log.*.gz; do
    if [ -f "$logfile" ]; then
        age_days=$(( ($(date +%s) - $(stat -c %Y "$logfile")) / 86400 ))

        if [ "$age_days" -gt 14 ]; then
            log_warn "Deleting $(basename "$logfile") (${age_days} days old)"
            rm -f "$logfile"
            ((nginx_deleted++))
        fi
    fi
done

log_info "Deleted $nginx_deleted old Nginx logs"

# 6. Summary
log_info "=== Log Rotation Summary ==="
pisignage_size=$(du -sh "$LOGS_DIR" | cut -f1)
nginx_size=$(du -sh /var/log/nginx 2>/dev/null | cut -f1 || echo "N/A")

log_info "PiSignage logs: $pisignage_size"
log_info "Nginx logs: $nginx_size"
log_info "Rotation completed successfully!"

# Log this rotation event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Log rotation completed - PiSignage: $pisignage_size, Nginx: $nginx_size" >> "$LOGS_DIR/system.log"

exit 0
