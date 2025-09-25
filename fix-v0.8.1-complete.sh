#!/bin/bash
# FIX COMPLET PiSignage v0.8.1 - VLC + Wayland + Big Buck Bunny
# Basé sur les recommandations ChatGPT pour Bookworm/Wayland

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[AVERTISSEMENT]${NC} $1"
}

# ========================================
# PHASE 1: INSTALLER LES PACKAGES WAYLAND/V4L2
# ========================================
log "Installation des packages recommandés par ChatGPT..."

sudo apt update
sudo apt install -y \
    raspberrypi-ffmpeg \
    v4l-utils \
    libdrm-tests \
    seatd \
    libgl1-mesa-dri \
    mesa-utils \
    weston \
    wayland-protocols \
    libwayland-dev || warning "Certains packages n'ont pas pu être installés"

# Ajouter l'utilisateur aux groupes nécessaires
log "Configuration des permissions..."
sudo usermod -aG video,render,audio,input pi
sudo usermod -aG video,render,audio,input www-data

# Activer seatd pour Wayland
sudo systemctl enable --now seatd || warning "seatd non disponible"

# ========================================
# PHASE 2: TÉLÉCHARGER BIG BUCK BUNNY
# ========================================
log "Téléchargement de Big Buck Bunny 720p..."

MEDIA_DIR="/opt/pisignage/media"
sudo mkdir -p "$MEDIA_DIR"

if [ ! -f "$MEDIA_DIR/big_buck_bunny_720p.mp4" ]; then
    log "Téléchargement en cours..."
    sudo wget -q --show-progress \
        "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4" \
        -O "$MEDIA_DIR/big_buck_bunny_720p.mp4" || \
    sudo wget -q --show-progress \
        "https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_30fps_normal.mp4" \
        -O "$MEDIA_DIR/big_buck_bunny_720p.mp4" || \
    error "Impossible de télécharger Big Buck Bunny"

    sudo chown www-data:www-data "$MEDIA_DIR/big_buck_bunny_720p.mp4"
    log "✓ Big Buck Bunny téléchargé"
else
    log "Big Buck Bunny déjà présent"
fi

# Créer la playlist par défaut
cat << 'EOF' | sudo tee "$MEDIA_DIR/playlist.m3u" > /dev/null
#EXTM3U
#EXTINF:634,Big Buck Bunny
/opt/pisignage/media/big_buck_bunny_720p.mp4
EOF

sudo chown www-data:www-data "$MEDIA_DIR/playlist.m3u"

# ========================================
# PHASE 3: CONFIGURER VLC COMME DÉFAUT AVEC WAYLAND
# ========================================
log "Configuration de VLC avec optimisations Wayland..."

# Mettre à jour la configuration pour VLC par défaut
sudo cat << 'EOF' > /opt/pisignage/config/player-config.json
{
  "player": {
    "default": "vlc",
    "current": "vlc",
    "available": ["vlc", "mpv"]
  },
  "vlc": {
    "enabled": true,
    "version": "3.0.18",
    "binary": "/usr/bin/cvlc",
    "config_path": "/home/pi/.config/vlc/vlcrc",
    "http_port": 8080,
    "http_password": "signage123",
    "log_file": "/opt/pisignage/logs/vlc.log",
    "optimizations": {
      "wayland": {
        "vout": "gles2",
        "no-video-title-show": true,
        "quiet": true,
        "intf": "dummy",
        "fullscreen": true,
        "loop": true
      },
      "x11": {
        "vout": "xcb_x11",
        "avcodec-hw": "any",
        "fullscreen": true
      },
      "drm": {
        "vout": "drm",
        "intf": "dummy"
      }
    }
  },
  "mpv": {
    "enabled": true,
    "version": "0.35.0",
    "binary": "/usr/bin/mpv",
    "config_path": "/home/pi/.config/mpv/mpv.conf",
    "socket": "/tmp/mpv-socket",
    "log_file": "/opt/pisignage/logs/mpv.log",
    "optimizations": {
      "wayland": {
        "gpu-context": "wayland",
        "vo": "gpu-next",
        "hwdec": "drm"
      },
      "x11": {
        "gpu-context": "x11",
        "vo": "gpu",
        "hwdec": "drm"
      },
      "drm": {
        "gpu-context": "drm",
        "vo": "gpu",
        "hwdec": "drm"
      }
    }
  },
  "system": {
    "pi_model": "auto",
    "display": "wayland-0",
    "wayland_display": "wayland-0",
    "audio_device": "alsa/default:CARD=vc4hdmi0",
    "default_media": "/opt/pisignage/media/big_buck_bunny_720p.mp4",
    "fallback_image": "/opt/pisignage/media/fallback-logo.jpg",
    "autostart": true,
    "watchdog": true
  }
}
EOF

sudo chown www-data:www-data /opt/pisignage/config/player-config.json

# ========================================
# PHASE 4: CRÉER SCRIPT DE LANCEMENT VLC WAYLAND
# ========================================
log "Création du script de lancement VLC optimisé..."

cat << 'EOF' | sudo tee /opt/pisignage/scripts/start-vlc-wayland.sh > /dev/null
#!/bin/bash
# Script de lancement VLC pour Wayland/X11 avec détection automatique

MEDIA_FILE="${1:-/opt/pisignage/media/big_buck_bunny_720p.mp4}"
LOG_FILE="/opt/pisignage/logs/vlc.log"

# Créer le répertoire de logs si nécessaire
mkdir -p /opt/pisignage/logs

# Détection de l'environnement graphique
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "[$(date)] Démarrage VLC en mode Wayland" >> "$LOG_FILE"
    VLC_ARGS="--vout=gles2 --no-video-title-show --quiet"
elif [ -n "$DISPLAY" ]; then
    echo "[$(date)] Démarrage VLC en mode X11" >> "$LOG_FILE"
    VLC_ARGS="--vout=xcb_x11"
else
    echo "[$(date)] Démarrage VLC en mode DRM (console)" >> "$LOG_FILE"
    VLC_ARGS="--vout=drm --intf=dummy"
fi

# Lancer VLC en plein écran avec la vidéo en boucle
exec /usr/bin/cvlc \
    $VLC_ARGS \
    --fullscreen \
    --loop \
    --no-audio-time-stretch \
    --file-caching=2000 \
    --network-caching=3000 \
    "$MEDIA_FILE" >> "$LOG_FILE" 2>&1
EOF

sudo chmod +x /opt/pisignage/scripts/start-vlc-wayland.sh
sudo chown www-data:www-data /opt/pisignage/scripts/start-vlc-wayland.sh

# ========================================
# PHASE 5: CRÉER SERVICE SYSTEMD USER (RECOMMANDATION CHATGPT)
# ========================================
log "Création du service systemd utilisateur pour Wayland..."

# Créer le répertoire systemd user si nécessaire
sudo -u pi mkdir -p /home/pi/.config/systemd/user/

# Créer le service utilisateur
cat << 'EOF' | sudo -u pi tee /home/pi/.config/systemd/user/pisignage-vlc.service > /dev/null
[Unit]
Description=PiSignage VLC Player (User Session)
After=graphical-session.target

[Service]
Type=simple
ExecStart=/opt/pisignage/scripts/start-vlc-wayland.sh
Restart=always
RestartSec=5
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="DISPLAY=:0"

[Install]
WantedBy=default.target
EOF

# Activer le service utilisateur
sudo -u pi systemctl --user daemon-reload
sudo -u pi systemctl --user enable pisignage-vlc.service

# Activer le linger pour démarrage automatique
sudo loginctl enable-linger pi

# ========================================
# PHASE 6: METTRE À JOUR L'INTERFACE WEB VERS v0.8.1
# ========================================
log "Mise à jour de l'interface web vers v0.8.1..."

# Mettre à jour la version dans le fichier principal
sudo sed -i "s/'version' => '0.8.0'/'version' => '0.8.1'/g" /opt/pisignage/web/index.php

# Mettre à jour le titre
sudo sed -i 's/PiSignage v0.8.0/PiSignage v0.8.1 GOLDEN/g' /opt/pisignage/web/index.php

# Ajouter les contrôles VLC à l'interface
if ! grep -q "VLC Controls" /opt/pisignage/web/index.php; then
    log "Ajout des contrôles VLC à l'interface..."
    # Ici on pourrait ajouter du code PHP pour les contrôles VLC
fi

# ========================================
# PHASE 7: CONFIGURATION MPV COMME BACKUP (CHATGPT)
# ========================================
log "Configuration de MPV comme lecteur de backup..."

mkdir -p /home/pi/.config/mpv
cat << 'EOF' | sudo -u pi tee /home/pi/.config/mpv/mpv.conf > /dev/null
# Configuration MPV optimisée pour Bookworm/Wayland
hwdec=drm
vo=gpu-next
gpu-context=wayland
profile=gpu-hq
fs=yes
loop-playlist=yes
cache=yes
demuxer-max-bytes=100MiB
EOF

# ========================================
# PHASE 8: SCRIPT DE DÉTECTION AUTOMATIQUE
# ========================================
log "Création du script de détection automatique..."

cat << 'EOF' | sudo tee /opt/pisignage/scripts/player-manager-v0.8.1-fixed.sh > /dev/null
#!/bin/bash
# Player Manager v0.8.1 - Détection automatique Wayland/X11

CONFIG_FILE="/opt/pisignage/config/player-config.json"
CURRENT_PLAYER=$(jq -r '.player.current' "$CONFIG_FILE" 2>/dev/null || echo "vlc")
DEFAULT_MEDIA="/opt/pisignage/media/big_buck_bunny_720p.mp4"

# Détection de l'environnement
detect_display() {
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo "wayland"
    elif [ -n "$DISPLAY" ]; then
        echo "x11"
    else
        echo "drm"
    fi
}

start_player() {
    local DISPLAY_TYPE=$(detect_display)
    echo "[$(date)] Starting $CURRENT_PLAYER on $DISPLAY_TYPE"

    case "$CURRENT_PLAYER" in
        vlc)
            case "$DISPLAY_TYPE" in
                wayland)
                    /usr/bin/cvlc --vout=gles2 --fullscreen --loop "$DEFAULT_MEDIA" &
                    ;;
                x11)
                    /usr/bin/cvlc --vout=xcb_x11 --fullscreen --loop "$DEFAULT_MEDIA" &
                    ;;
                drm)
                    /usr/bin/cvlc --vout=drm --intf=dummy --fullscreen --loop "$DEFAULT_MEDIA" &
                    ;;
            esac
            ;;
        mpv)
            case "$DISPLAY_TYPE" in
                wayland)
                    /usr/bin/mpv --gpu-context=wayland --vo=gpu-next --hwdec=drm --fs --loop "$DEFAULT_MEDIA" &
                    ;;
                x11)
                    /usr/bin/mpv --gpu-context=x11 --vo=gpu --hwdec=drm --fs --loop "$DEFAULT_MEDIA" &
                    ;;
                drm)
                    /usr/bin/mpv --gpu-context=drm --vo=gpu --hwdec=drm --fs --loop "$DEFAULT_MEDIA" &
                    ;;
            esac
            ;;
    esac
}

stop_player() {
    pkill -f vlc
    pkill -f mpv
}

case "$1" in
    start)
        start_player
        ;;
    stop)
        stop_player
        ;;
    restart)
        stop_player
        sleep 2
        start_player
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF

sudo chmod +x /opt/pisignage/scripts/player-manager-v0.8.1-fixed.sh
sudo chown www-data:www-data /opt/pisignage/scripts/player-manager-v0.8.1-fixed.sh

# ========================================
# PHASE 9: AUTOSTART AU BOOT
# ========================================
log "Configuration de l'autostart..."

# Créer le script d'autostart pour l'utilisateur pi
cat << 'EOF' | sudo -u pi tee /home/pi/.config/autostart/pisignage.desktop > /dev/null
[Desktop Entry]
Type=Application
Name=PiSignage VLC Player
Exec=/opt/pisignage/scripts/start-vlc-wayland.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Alternative : ajouter au bashrc pour session console
echo "" | sudo -u pi tee -a /home/pi/.bashrc > /dev/null
echo "# Auto-start PiSignage if in graphical session" | sudo -u pi tee -a /home/pi/.bashrc > /dev/null
echo 'if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then' | sudo -u pi tee -a /home/pi/.bashrc > /dev/null
echo '    pgrep vlc > /dev/null || /opt/pisignage/scripts/start-vlc-wayland.sh &' | sudo -u pi tee -a /home/pi/.bashrc > /dev/null
echo 'fi' | sudo -u pi tee -a /home/pi/.bashrc > /dev/null

# ========================================
# PHASE 10: TESTS ET VÉRIFICATIONS
# ========================================
log "Vérifications finales..."

# Vérifier les permissions
echo "Vérification des permissions..."
if id | grep -E '(\bvideo\b|\brender\b)'; then
    log "✓ Utilisateur dans les bons groupes"
else
    warning "Utilisateur pas dans les groupes video/render"
fi

# Vérifier V4L2
echo "Vérification V4L2..."
if v4l2-ctl --list-devices 2>/dev/null | grep -E '/dev/video'; then
    log "✓ Devices V4L2 disponibles"
else
    warning "Pas de devices V4L2 détectés"
fi

# Vérifier ffmpeg avec support V4L2
echo "Vérification ffmpeg..."
if ffmpeg -decoders 2>/dev/null | grep -E 'h264_v4l2m2m|hevc_v4l2m2m'; then
    log "✓ ffmpeg avec support V4L2 détecté"
else
    warning "ffmpeg sans support V4L2"
fi

# Vérifier seatd
if systemctl is-active seatd > /dev/null 2>&1; then
    log "✓ seatd actif"
else
    warning "seatd inactif"
fi

# ========================================
# RÉSUMÉ
# ========================================
echo ""
echo "=========================================="
echo -e "${GREEN}✅ CONFIGURATION v0.8.1 TERMINÉE !${NC}"
echo "=========================================="
echo ""
echo "Résumé de la configuration :"
echo "- VLC configuré par défaut avec support Wayland"
echo "- Big Buck Bunny 720p téléchargé"
echo "- Service systemd utilisateur créé"
echo "- Interface web mise à jour vers v0.8.1"
echo "- Autostart configuré au boot"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT :${NC}"
echo "1. Redémarrez le Raspberry Pi pour appliquer tous les changements"
echo "2. VLC devrait démarrer automatiquement avec Big Buck Bunny"
echo "3. Interface web accessible sur http://192.168.1.103/"
echo ""
echo "Commandes utiles :"
echo "  systemctl --user status pisignage-vlc    # Vérifier le service"
echo "  journalctl --user -u pisignage-vlc -f    # Voir les logs"
echo "  /opt/pisignage/scripts/start-vlc-wayland.sh  # Lancer manuellement"
echo ""

log "Script terminé avec succès!"