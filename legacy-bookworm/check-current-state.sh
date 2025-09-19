#!/bin/bash

echo "=== VERIFICATION DE L'ETAT ACTUEL ==="

sshpass -p palmer00 ssh -o StrictHostKeyChecking=no pi@192.168.1.106 << 'EOF' 2>/dev/null
echo "Checking what's running..."
ps aux | grep -E "(lightdm|nodm|Xorg|chromium)" | grep -v grep | head -5
echo ""
echo "Active display manager:"
ls -l /etc/X11/default-display-manager 2>/dev/null
echo ""
echo "Current target:"
systemctl get-default
echo ""
echo "Kiosk service:"
systemctl status kiosk.service --no-pager 2>/dev/null | head -3
EOF