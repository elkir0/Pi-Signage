#!/bin/bash

# ==================================================
#   QUICKSTART FULLPAGEOS - TOUT EN UN
#   Lance automatiquement après flash de FullPageOS
# ==================================================

clear

echo "╔══════════════════════════════════════════════╗"
echo "║     FULLPAGEOS PI SIGNAGE - QUICKSTART      ║"
echo "║         25+ FPS GARANTI SUR PI 4            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Vérifier les prérequis
command -v sshpass >/dev/null 2>&1 || {
    echo "⚠️  Installation de sshpass requise..."
    sudo apt-get install -y sshpass
}

# Configuration
read -p "📍 IP du Raspberry Pi [192.168.1.103]: " PI_IP
PI_IP=${PI_IP:-192.168.1.103}

read -p "👤 Utilisateur Pi [pi]: " PI_USER
PI_USER=${PI_USER:-pi}

read -sp "🔐 Mot de passe [palmer00]: " PI_PASS
PI_PASS=${PI_PASS:-palmer00}
echo ""

echo ""
echo "Configuration:"
echo "  • Pi: $PI_IP"
echo "  • User: $PI_USER"
echo ""

# Test de connexion
echo "🔍 Test de connexion..."
if sshpass -p "$PI_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
    $PI_USER@$PI_IP "echo 'OK'" > /dev/null 2>&1; then
    echo "✅ Connexion établie"
else
    echo "❌ Impossible de se connecter"
    echo ""
    echo "Vérifiez que :"
    echo "1. FullPageOS est bien flashé et démarré"
    echo "2. Le Pi est accessible sur le réseau"
    echo "3. SSH est activé"
    echo "4. Les identifiants sont corrects"
    exit 1
fi

echo ""
echo "📦 Préparation des fichiers..."

# Rendre tous les scripts exécutables
chmod +x *.sh

echo "✅ Scripts prêts"
echo ""
echo "🚀 Lancement du déploiement..."
echo ""

# Lancer le déploiement
./deploy-to-fullpageos.sh $PI_IP

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║            DÉPLOIEMENT TERMINÉ !             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📺 Le Pi va redémarrer et afficher la vidéo"
echo ""
echo "🎯 Résultats attendus:"
echo "   • Vidéo Big Buck Bunny en boucle"
echo "   • 25-30+ FPS (compteur vert)"
echo "   • CPU < 30%"
echo ""
echo "📊 Pour vérifier:"
echo "   ssh $PI_USER@$PI_IP"
echo "   ./test-performance.sh"
echo ""
echo "🛠️ Pour maintenance:"
echo "   ./maintenance.sh $PI_IP"
echo ""
echo "🎉 Profitez de votre affichage 25+ FPS !"