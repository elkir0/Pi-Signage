#!/bin/bash
#
# Setup daily log rotation cron job
# Run this script once to install the cron job
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROTATE_SCRIPT="$SCRIPT_DIR/rotate-logs.sh"
CRON_FILE="/etc/cron.daily/pisignage-rotate-logs"

echo "Setting up PiSignage log rotation cron job..."

# Check if rotate script exists
if [ ! -f "$ROTATE_SCRIPT" ]; then
    echo "ERROR: rotate-logs.sh not found at $ROTATE_SCRIPT"
    exit 1
fi

# Make rotate script executable
chmod +x "$ROTATE_SCRIPT"
echo "✓ Made rotate-logs.sh executable"

# Create cron.daily script
sudo tee "$CRON_FILE" > /dev/null << EOF
#!/bin/bash
# PiSignage Log Rotation - Runs daily at 3am
# Installed by setup-log-rotation-cron.sh

$ROTATE_SCRIPT >> /opt/pisignage/logs/rotation.log 2>&1
EOF

# Make cron script executable
sudo chmod +x "$CRON_FILE"
echo "✓ Created cron.daily script at $CRON_FILE"

# Test the rotation script (dry run info)
echo ""
echo "Testing rotation script..."
echo "Current log sizes:"
du -sh /opt/pisignage/logs/
du -sh /var/log/nginx/ 2>/dev/null || echo "Nginx logs: N/A"

echo ""
echo "✓ Log rotation cron job installed successfully!"
echo ""
echo "The script will run daily at 3am to:"
echo "  - Rotate logs larger than 10MB"
echo "  - Delete YouTube logs older than 7 days"
echo "  - Delete rotated logs older than 30 days"
echo "  - Rotate Nginx logs larger than 50MB"
echo "  - Delete old Nginx logs older than 14 days"
echo ""
echo "To run manually: sudo $ROTATE_SCRIPT"
echo "To view rotation log: cat /opt/pisignage/logs/rotation.log"
