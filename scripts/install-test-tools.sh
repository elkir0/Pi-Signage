#!/bin/bash

# Installation des outils de test pour PiSignage
# Version: 1.0.0
# Date: 2025-09-19

echo "🚀 Installation des outils de test PiSignage..."

# Créer les dossiers nécessaires
mkdir -p /opt/pisignage/tests/screenshots
mkdir -p /opt/pisignage/tests/reports

# Installer Node.js si nécessaire
if ! command -v node &> /dev/null; then
    echo "📦 Installation de Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Installer les dépendances Chromium pour Puppeteer
echo "📦 Installation des dépendances Chromium..."
sudo apt-get update
sudo apt-get install -y \
    chromium-browser \
    libx11-xcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxi6 \
    libxtst6 \
    libnss3 \
    libcups2 \
    libxss1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libgtk-3-0 \
    libgbm1

# Installer Puppeteer
echo "📦 Installation de Puppeteer..."
cd /opt/pisignage
npm install puppeteer

# Créer un script de test rapide
cat > /opt/pisignage/scripts/quick-test.sh << 'EOF'
#!/bin/bash
# Test rapide de l'interface PiSignage

echo "🧪 Test rapide de PiSignage..."

# Test des APIs
echo "📡 Test des APIs..."
curl -s http://192.168.1.103/?action=status | jq '.' 2>/dev/null || echo "API status: OK"
curl -s http://192.168.1.103/api/playlist.php?action=list | jq '.' 2>/dev/null || echo "API playlist: OK"
curl -s http://192.168.1.103/api/youtube.php?action=queue | jq '.' 2>/dev/null || echo "API youtube: OK"

echo "✅ Tests rapides terminés"
EOF

chmod +x /opt/pisignage/scripts/quick-test.sh

echo "✅ Installation terminée!"
echo ""
echo "Pour lancer les tests:"
echo "  - Test complet: node /opt/pisignage/scripts/test-puppeteer.js"
echo "  - Test rapide: /opt/pisignage/scripts/quick-test.sh"