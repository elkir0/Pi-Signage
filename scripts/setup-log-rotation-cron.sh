#!/bin/bash
#
# Install PiSignage log rotation via standard logrotate + systemd timer.
# Run this script once to install/refresh the configuration. It is idempotent.
#
# Replaces the previous cron.daily + home-grown rotation approach with:
#   - /etc/logrotate.d/pisignage           (size/compression/age policy)
#   - pisignage-logrotate.service          (oneshot: runs logrotate)
#   - pisignage-logrotate.timer            (daily trigger at 03:00)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROTATE_SCRIPT="$SCRIPT_DIR/rotate-logs.sh"

LOGROTATE_CONF="/etc/logrotate.d/pisignage"
OLD_CRON_FILE="/etc/cron.daily/pisignage-rotate-logs"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_FILE="$SYSTEMD_DIR/pisignage-logrotate.service"
TIMER_FILE="$SYSTEMD_DIR/pisignage-logrotate.timer"

echo "Setting up PiSignage log rotation (logrotate + systemd timer)..."

# Make the compat wrapper executable (still used by the web UI for manual runs).
if [ -f "$ROTATE_SCRIPT" ]; then
    chmod +x "$ROTATE_SCRIPT"
    echo "✓ Made rotate-logs.sh executable"
fi

# Remove the obsolete cron.daily entry from the previous approach.
if [ -f "$OLD_CRON_FILE" ]; then
    sudo rm -f "$OLD_CRON_FILE"
    echo "✓ Removed obsolete cron.daily script ($OLD_CRON_FILE)"
fi

# 1. Install the logrotate policy.
sudo tee "$LOGROTATE_CONF" > /dev/null << 'EOF'
# PiSignage application logs
/opt/pisignage/logs/*.log {
    daily
    rotate 30
    maxsize 10M
    missingok
    notifempty
    compress
    copytruncate
    su www-data www-data
    create 0644 www-data www-data
    # copytruncate rend la rotation immédiate -> pas de delaycompress (gaspille du disque).
    # Archives supprimées au-delà de 30 jours.
    maxage 30
}

# Nginx logs serving the PiSignage web UI
/var/log/nginx/*.log {
    daily
    rotate 14
    maxsize 50M
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        [ -f /run/nginx.pid ] && kill -USR1 "$(cat /run/nginx.pid)" 2>/dev/null || true
    endscript
}
EOF
echo "✓ Installed logrotate config at $LOGROTATE_CONF"

# Validate the logrotate config (debug mode does not modify anything).
if command -v logrotate >/dev/null 2>&1; then
    if sudo logrotate --debug "$LOGROTATE_CONF" >/dev/null 2>&1; then
        echo "✓ logrotate config validated"
    else
        echo "⚠ logrotate reported issues with the config (continuing)"
    fi
fi

# 2. Install the systemd service (oneshot logrotate run).
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=PiSignage log rotation (logrotate)
Documentation=file://$LOGROTATE_CONF

[Service]
Type=oneshot
ExecStart=/usr/sbin/logrotate /etc/logrotate.d/pisignage --state /var/lib/logrotate/pisignage.status
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF
echo "✓ Installed systemd service at $SERVICE_FILE"

# 3. Install the systemd timer (daily at 03:00, catch-up if missed).
sudo tee "$TIMER_FILE" > /dev/null << 'EOF'
[Unit]
Description=PiSignage daily log rotation timer

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF
echo "✓ Installed systemd timer at $TIMER_FILE"

# 4. Enable and start the timer.
sudo systemctl daemon-reload
sudo systemctl enable --now pisignage-logrotate.timer
echo "✓ Enabled pisignage-logrotate.timer"

echo ""
echo "Current log sizes:"
du -sh /opt/pisignage/logs/ 2>/dev/null || echo "PiSignage logs: N/A"
du -sh /var/log/nginx/ 2>/dev/null || echo "Nginx logs: N/A"

echo ""
echo "✓ Log rotation installed successfully (logrotate + systemd timer)!"
echo ""
echo "Policy:"
echo "  - PiSignage logs rotate daily or at >10MB, kept 30 days, compressed"
echo "  - Nginx logs rotate daily or at >50MB, kept 14 days, compressed"
echo ""
echo "Timer status:   systemctl status pisignage-logrotate.timer"
echo "Next run:       systemctl list-timers pisignage-logrotate.timer"
echo "Run manually:   sudo systemctl start pisignage-logrotate.service"
echo "                (or sudo $ROTATE_SCRIPT  -- used by the web UI)"
