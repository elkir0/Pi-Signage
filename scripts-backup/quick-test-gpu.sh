#!/bin/bash

# Test rapide configuration GPU actuelle
set -e

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "=== TEST CONFIGURATION GPU ACTUELLE ==="

echo "1. Configuration GPU:"
sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "vcgencmd get_mem gpu && vcgencmd measure_temp && vcgencmd measure_clock arm && vcgencmd measure_clock gpu"

echo ""
echo "2. Processus Chromium:"
sshpass -p "$PI_PASS" ssh "$PI_USER@$PI_IP" "pgrep -f chromium-browser && ps aux | grep chromium | head -1" || echo "Chromium non trouvé"

echo ""
echo "3. Test API Performance:"
curl -s "http://$PI_IP/api/performance.php?endpoint=gpu" | head -5 || echo "API non accessible"

echo ""
echo "=== TEST TERMINÉ ==="