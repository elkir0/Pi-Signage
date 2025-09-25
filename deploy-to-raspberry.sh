#!/bin/bash
# PiSignage v0.8.1 - Script de déploiement vers Raspberry Pi

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "🚀 PiSignage v0.8.1 - Déploiement vers Raspberry Pi"
echo "═══════════════════════════════════════════════════════════════"

# Configuration
RASPBERRY_IP="192.168.1.103"
RASPBERRY_USER="pi"
RASPBERRY_PASS="raspberry"
REMOTE_PATH="/opt/pisignage"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Vérifier la connectivité
echo "📡 Test de connexion au Raspberry Pi..."
if ping -c 1 $RASPBERRY_IP &> /dev/null; then
    log_info "Raspberry Pi accessible à $RASPBERRY_IP"
else
    log_error "Impossible de joindre le Raspberry Pi à $RASPBERRY_IP"
    exit 1
fi

# Créer une archive des fichiers modifiés
echo "📦 Création de l'archive de déploiement..."
TEMP_ARCHIVE="/tmp/pisignage-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"

# Liste des fichiers et dossiers à déployer
FILES_TO_DEPLOY=(
    "web/index.php"
    "web/api/screenshot-raspi2png.php"
    "config/player-config.json"
    "scripts/start-vlc-bbb.sh"
    "CLAUDE.md"
)

# Créer l'archive
tar -czf "$TEMP_ARCHIVE" \
    --transform 's,^,pisignage/,' \
    -C /opt \
    "${FILES_TO_DEPLOY[@]/#/pisignage/}" 2>/dev/null || true

log_info "Archive créée: $TEMP_ARCHIVE"

# Transférer l'archive vers le Raspberry Pi
echo "📤 Transfert des fichiers vers le Raspberry Pi..."
sshpass -p "$RASPBERRY_PASS" scp -o StrictHostKeyChecking=no \
    "$TEMP_ARCHIVE" \
    "$RASPBERRY_USER@$RASPBERRY_IP:/tmp/" || {
    log_error "Échec du transfert. Assurez-vous que sshpass est installé et que les identifiants sont corrects."
    exit 1
}

log_info "Archive transférée avec succès"

# Déployer sur le Raspberry Pi
echo "🔧 Déploiement sur le Raspberry Pi..."
sshpass -p "$RASPBERRY_PASS" ssh -o StrictHostKeyChecking=no \
    "$RASPBERRY_USER@$RASPBERRY_IP" << 'EOF'
    set -e
    echo "📂 Extraction des fichiers..."

    # Créer une sauvegarde
    BACKUP_DIR="/opt/pisignage/backups/$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$BACKUP_DIR"

    # Sauvegarder les fichiers actuels
    if [ -f /opt/pisignage/web/index.php ]; then
        sudo cp /opt/pisignage/web/index.php "$BACKUP_DIR/" 2>/dev/null || true
    fi

    # Extraire la nouvelle version
    cd /tmp
    ARCHIVE=$(ls -t pisignage-deploy-*.tar.gz 2>/dev/null | head -1)
    if [ -n "$ARCHIVE" ]; then
        sudo tar -xzf "$ARCHIVE" -C /opt/
        echo "✓ Fichiers extraits"

        # Nettoyer
        rm "$ARCHIVE"
    fi

    # Définir les permissions
    sudo chown -R pi:pi /opt/pisignage/
    sudo chmod +x /opt/pisignage/scripts/*.sh 2>/dev/null || true

    # Redémarrer le serveur web
    echo "🔄 Redémarrage du serveur web..."
    if systemctl is-active --quiet nginx; then
        sudo systemctl restart nginx
        echo "✓ Nginx redémarré"
    elif systemctl is-active --quiet apache2; then
        sudo systemctl restart apache2
        echo "✓ Apache2 redémarré"
    else
        # Essayer avec PHP built-in server
        pkill -f "php -S" 2>/dev/null || true
        cd /opt/pisignage/web
        nohup php -S 0.0.0.0:80 index.php > /opt/pisignage/logs/php-server.log 2>&1 &
        echo "✓ Serveur PHP redémarré"
    fi

    # Redémarrer VLC avec BBB
    echo "🎬 Redémarrage de VLC avec Big Buck Bunny..."
    pkill -9 vlc 2>/dev/null || true
    pkill -9 mpv 2>/dev/null || true
    sleep 1

    if [ -f /opt/pisignage/scripts/start-vlc-bbb.sh ]; then
        /opt/pisignage/scripts/start-vlc-bbb.sh &
        echo "✓ VLC redémarré avec BBB"
    fi

    echo "✅ Déploiement terminé avec succès!"
EOF

# Nettoyer l'archive locale
rm -f "$TEMP_ARCHIVE"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ DÉPLOIEMENT RÉUSSI!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📝 Résumé des actions:"
echo "  • Version déployée: v0.8.1"
echo "  • Fichiers mis à jour: ${#FILES_TO_DEPLOY[@]}"
echo "  • Raspberry Pi: $RASPBERRY_IP"
echo ""
echo "🔍 Pour tester:"
echo "  1. Interface web: http://$RASPBERRY_IP/"
echo "  2. Test Puppeteer: node /opt/pisignage/test-puppeteer.js"
echo "  3. Logs VLC: ssh $RASPBERRY_USER@$RASPBERRY_IP 'tail -f /opt/pisignage/logs/vlc.log'"
echo ""
echo "💡 Commandes utiles:"
echo "  • Vérifier VLC: ssh $RASPBERRY_USER@$RASPBERRY_IP 'pgrep -f vlc'"
echo "  • Screenshots: ssh $RASPBERRY_USER@$RASPBERRY_IP 'ls -la /dev/shm/pisignage-screenshots/'"
echo "  • Redémarrer: ssh $RASPBERRY_USER@$RASPBERRY_IP 'sudo reboot'"
echo ""

exit 0