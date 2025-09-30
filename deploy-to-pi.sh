#!/bin/bash
# PiSignage Deployment Script
# Déploie le code sur Raspberry Pi 192.168.1.105

echo "🚀 PiSignage Deployment Script"
echo "=============================="
echo ""

# Configuration
PI_HOST="pi@192.168.1.105"
PI_DIR="/opt/pisignage"

echo "📋 Étape 1: Connexion au Raspberry Pi..."
echo "Host: $PI_HOST"
echo "Remote directory: $PI_DIR"
echo ""

# Vérifier la connexion
if ! ssh -o ConnectTimeout=5 $PI_HOST "echo 'Connected'" 2>/dev/null; then
    echo "❌ Impossible de se connecter au Raspberry Pi"
    echo "Vérifiez:"
    echo "  - Le Pi est allumé et connecté"
    echo "  - L'IP est correcte (192.168.1.105)"
    echo "  - SSH est activé sur le Pi"
    echo "  - Utilisez: ssh-copy-id $PI_HOST"
    exit 1
fi

echo "✅ Connexion réussie"
echo ""

echo "📥 Étape 2: Synchronisation Git sur le Pi..."
ssh $PI_HOST "cd $PI_DIR && git pull origin main" || {
    echo "❌ Erreur lors du git pull"
    exit 1
}

echo "✅ Code synchronisé"
echo ""

echo "📁 Étape 3: Vérification fichiers déployés..."
ssh $PI_HOST "ls -lh $PI_DIR/web/api/schedule.php $PI_DIR/web/schedule.php $PI_DIR/web/assets/js/schedule.js"

echo ""
echo "🔧 Étape 4: Configuration permissions..."
ssh $PI_HOST "sudo chown -R www-data:www-data $PI_DIR/data && sudo chmod 666 $PI_DIR/data/schedules.json" 2>/dev/null

echo ""
echo "🔄 Étape 5: Rechargement nginx..."
ssh $PI_HOST "sudo systemctl reload nginx"

echo ""
echo "✅ Déploiement terminé avec succès!"
echo ""
echo "📊 Accédez au module Scheduler:"
echo "   http://192.168.1.105/schedule.php"
echo ""
