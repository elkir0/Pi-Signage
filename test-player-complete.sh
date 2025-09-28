#!/bin/bash
###############################################################################
# PiSignage - Complete Player Test Script
###############################################################################

echo "======================================="
echo "PiSignage Player Complete Test"
echo "======================================="

# Get Pi IP
PI_IP="192.168.1.103"

echo "1. Testing Player API Status:"
curl -s http://$PI_IP/api/player-control.php?action=status | python3 -m json.tool 2>/dev/null | head -20 || echo "API Error"

echo -e "\n2. Testing Play Command:"
curl -s -X POST http://$PI_IP/api/player-control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"play"}' | python3 -m json.tool 2>/dev/null || echo "Play Error"

echo -e "\n3. Testing Volume Control:"
curl -s -X POST http://$PI_IP/api/player-control.php \
  -H "Content-Type: application/json" \
  -d '{"action":"volume","params":{"volume":75}}' | python3 -m json.tool 2>/dev/null | grep -E "success|volume" || echo "Volume Error"

echo -e "\n4. Testing Media List:"
curl -s http://$PI_IP/api/media.php | python3 -m json.tool 2>/dev/null | head -15 || echo "Media Error"

echo -e "\n5. Testing Playlist List:"
curl -s http://$PI_IP/api/playlist-simple.php | python3 -m json.tool 2>/dev/null | head -15 || echo "Playlist Error"

echo -e "\n6. Testing System Stats:"
curl -s http://$PI_IP/api/system.php?action=stats | python3 -m json.tool 2>/dev/null | grep -E "cpu|memory|temperature" | head -10 || echo "Stats Error"

echo -e "\n======================================="
echo "Test Complete!"
echo "Access the interface at: http://$PI_IP/"
echo "Navigate to 'Lecteur' section to test controls"