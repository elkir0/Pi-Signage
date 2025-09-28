#!/bin/bash
# PiSignage Raspberry Pi Test Script

echo "==================================="
echo "PiSignage Raspberry Pi Test Suite"
echo "==================================="

# Check if on Raspberry Pi
if [[ -f /proc/device-tree/model ]]; then
    MODEL=$(cat /proc/device-tree/model)
    echo "✓ Hardware: $MODEL"
else
    echo "✗ Not on Raspberry Pi - Tests limited"
fi

# Test services
echo -e "\n--- Service Status ---"
systemctl is-active nginx && echo "✓ Nginx running" || echo "✗ Nginx stopped"
systemctl is-active php*-fpm && echo "✓ PHP-FPM running" || echo "✗ PHP-FPM stopped"

# Test API
echo -e "\n--- API Test ---"
curl -s http://localhost/api/system.php?action=stats | grep -q success && echo "✓ API working" || echo "✗ API failed"

# Test VLC
echo -e "\n--- VLC Test ---"
which vlc && echo "✓ VLC installed" || echo "✗ VLC missing"

echo -e "\n==================================="
echo "Test complete!"
