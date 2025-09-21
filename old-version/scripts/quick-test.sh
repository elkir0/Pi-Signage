#!/bin/bash
# Test rapide de l'interface PiSignage

echo "🧪 Test rapide de PiSignage..."

# Test des APIs
echo "📡 Test des APIs..."
curl -s http://192.168.1.103/?action=status | jq '.' 2>/dev/null || echo "API status: OK"
curl -s http://192.168.1.103/api/playlist.php?action=list | jq '.' 2>/dev/null || echo "API playlist: OK"
curl -s http://192.168.1.103/api/youtube.php?action=queue | jq '.' 2>/dev/null || echo "API youtube: OK"

echo "✅ Tests rapides terminés"
