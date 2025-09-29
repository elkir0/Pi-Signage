#!/bin/bash
# Synchronisation depuis le Raspberry Pi vers local/GitHub

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

echo "📥 Synchronisation depuis Raspberry Pi..."

# Liste des fichiers modifiés sur le Pi
FILES_TO_SYNC=(
    "web/includes/footer.php"
    "web/api/test-stats.php"
    "web/api/screenshot-vlc.php"
    "web/api/system-functions.php"
    "web/test_vlc.php"
)

for file in "${FILES_TO_SYNC[@]}"; do
    echo "Syncing $file..."
    sshpass -p $PI_PASS scp $PI_USER@$PI_IP:/opt/pisignage/$file /opt/pisignage/$file 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ $file synchronized"
    else
        echo "⚠️  $file not found or unchanged"
    fi
done

echo ""
echo "📋 Fichiers synchronisés. Vérification des changements..."
git status --short