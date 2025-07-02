#!/bin/bash

# Script pour créer le service chromium-kiosk manquant

echo "=== Création du service chromium-kiosk ==="

# Créer le service systemd
cat > /etc/systemd/system/chromium-kiosk.service << 'EOF'
[Unit]
Description=Chromium Kiosk Mode
After=graphical.target network.target
Wants=graphical.target

[Service]
Type=simple
User=pi
Group=pi
Environment="HOME=/home/pi"
Environment="DISPLAY=:0"
ExecStart=/opt/scripts/chromium-kiosk.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# Recharger systemd
systemctl daemon-reload

# NE PAS activer le service car le boot manager s'en occupe
echo "Service créé mais non activé (géré par pi-signage-startup)"

# Vérifier
if [[ -f /etc/systemd/system/chromium-kiosk.service ]]; then
    echo "✓ Service chromium-kiosk créé avec succès"
    echo ""
    echo "Le service sera démarré automatiquement par pi-signage-startup au boot"
else
    echo "✗ Échec de création du service"
fi