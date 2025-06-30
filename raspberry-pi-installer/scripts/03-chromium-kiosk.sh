#!/usr/bin/env bash

# =============================================================================
# Module 03 - Installation Chromium en mode Kiosk
# Version: 1.0.0
# Description: Alternative moderne à VLC avec Chromium en mode kiosk
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly KIOSK_SCRIPT="/opt/scripts/chromium-kiosk.sh"
readonly PLAYER_DIR="/var/www/pi-signage-player"
readonly SERVICE_FILE="/etc/systemd/system/chromium-kiosk.service"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
else
    echo "ERREUR: Fichier de sécurité manquant: 00-security-utils.sh" >&2
    exit 1
fi

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING
# =============================================================================

log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [INFO] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${GREEN}[CHROMIUM]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[CHROMIUM]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[CHROMIUM]${NC} $*" >&2
}

# =============================================================================
# CHARGEMENT DE LA CONFIGURATION
# =============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration chargée"
    else
        log_error "Fichier de configuration introuvable"
        return 1
    fi
}

# =============================================================================
# INSTALLATION DE CHROMIUM
# =============================================================================

install_chromium() {
    log_info "Installation de Chromium..."
    
    # Paquets nécessaires pour Chromium kiosk
    local packages=(
        "chromium-browser"
        "xserver-xorg-core"
        "xserver-xorg-video-fbdev"
        "xinit"
        "x11-xserver-utils"
        "unclutter"
        "nginx"  # Pour servir le player local
        "jq"     # Pour manipuler JSON
    )
    
    # Détection VM et ajout xvfb si nécessaire
    if [[ -f /etc/pi-signage/vm-mode.conf ]] || ! [[ -f /proc/device-tree/model ]]; then
        log_info "Mode VM détecté, ajout de Xvfb pour display virtuel"
        packages+=("xvfb")
    fi
    
    # Installation avec retry
    local install_cmd="apt-get update && apt-get install -y ${packages[*]}"
    if safe_execute "$install_cmd" 3 10; then
        log_info "Chromium et dépendances installés avec succès"
    else
        log_error "Échec de l'installation de Chromium"
        return 1
    fi
    
    # Vérification
    if command -v chromium-browser >/dev/null 2>&1; then
        local version
        version=$(chromium-browser --version 2>/dev/null || echo "Version inconnue")
        log_info "Chromium disponible: $version"
    else
        log_error "Chromium non disponible après installation"
        return 1
    fi
}

# =============================================================================
# CRÉATION DU SCRIPT DE DÉMARRAGE KIOSK
# =============================================================================

create_kiosk_script() {
    log_info "Création du script de démarrage kiosk..."
    
    cat > "$KIOSK_SCRIPT" << 'EOF'
#!/usr/bin/env bash

# =============================================================================
# Script de démarrage Chromium Kiosk
# =============================================================================

# Configuration
PLAYER_URL="http://localhost:8888/player.html"
LOG_FILE="/var/log/pi-signage/chromium.log"
USER="pi"

# Fonction de logging
log_kiosk() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Fonction de nettoyage
cleanup() {
    log_kiosk "Arrêt de Chromium Kiosk"
    pkill -f chromium-browser || true
    # Arrêter Xvfb si démarré
    if [[ -n "${XVFB_PID:-}" ]]; then
        kill $XVFB_PID 2>/dev/null || true
    fi
    exit 0
}

# Gestionnaire de signaux
trap cleanup SIGTERM SIGINT

# Initialisation
log_kiosk "=== Démarrage Chromium Kiosk ==="

# Variables d'environnement pour X11
export DISPLAY=:0
export XAUTHORITY=/home/$USER/.Xauthority

# Créer le répertoire de logs
mkdir -p "$(dirname "$LOG_FILE")"

# Détecter si on est en mode VM et démarrer Xvfb si nécessaire
if [[ -f /etc/pi-signage/vm-mode.conf ]] || ! [[ -f /proc/device-tree/model ]]; then
    log_kiosk "Mode VM détecté, démarrage de Xvfb"
    # Tuer tout Xvfb existant
    pkill -f Xvfb || true
    # Démarrer Xvfb en arrière-plan
    Xvfb :0 -screen 0 1920x1080x24 &
    XVFB_PID=$!
    sleep 2
    export DISPLAY=:0
fi

# Attendre que X11 soit prêt
for i in {1..30}; do
    if xset q &>/dev/null; then
        log_kiosk "X11 disponible après $i secondes"
        break
    fi
    sleep 1
done

# Désactiver l'économiseur d'écran et le DPMS
xset s off
xset -dpms
xset s noblank

# Masquer le curseur après 1 seconde d'inactivité
unclutter -idle 1 &

# Nettoyer les profils Chromium précédents
rm -rf /home/$USER/.cache/chromium
rm -rf /home/$USER/.config/chromium

# Options Chromium optimisées pour Raspberry Pi
CHROMIUM_FLAGS=(
    --kiosk
    --noerrdialogs
    --disable-infobars
    --disable-session-crashed-bubble
    --disable-translate
    --no-first-run
    --fast
    --fast-start
    --disable-features=TranslateUI
    --disk-cache-dir=/tmp/chromium-cache
    --overscroll-history-navigation=0
    --disable-pinch
    --autoplay-policy=no-user-gesture-required
    --window-size=1920,1080
    --window-position=0,0
    --check-for-update-interval=31536000
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-renderer-backgrounding
    --disable-features=Translate
    --disable-ipc-flooding-protection
    --disable-background-networking
    --enable-features=OverlayScrollbar
    --start-maximized
    --user-data-dir=/tmp/chromium-kiosk
)

# Optimisations pour Raspberry Pi
case "$PI_MODEL" in
    "3B+")
        CHROMIUM_FLAGS+=(
            --max-old-space-size=256
            --disable-gpu-sandbox
            --disable-software-rasterizer
            --disable-dev-shm-usage
        )
        ;;
    "4B"|"5")
        CHROMIUM_FLAGS+=(
            --enable-hardware-acceleration
            --enable-gpu-rasterization
            --enable-native-gpu-memory-buffers
        )
        ;;
esac

# Fonction de démarrage de Chromium
start_chromium() {
    log_kiosk "Démarrage de Chromium avec URL: $PLAYER_URL"
    
    # Démarrer Chromium
    chromium-browser "${CHROMIUM_FLAGS[@]}" "$PLAYER_URL" \
        2>&1 | while IFS= read -r line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') [CHROMIUM] $line" >> "$LOG_FILE"
        done
    
    # Si Chromium se ferme, log et attendre avant de redémarrer
    log_kiosk "Chromium fermé, redémarrage dans 5 secondes..."
    sleep 5
}

# Boucle principale avec récupération automatique
while true; do
    start_chromium
done
EOF
    
    # Rendre exécutable
    chmod +x "$KIOSK_SCRIPT"
    
    # S'assurer que le répertoire /opt/scripts est accessible
    chmod 755 /opt/scripts
    
    log_info "Script kiosk créé: $KIOSK_SCRIPT"
}

# =============================================================================
# CRÉATION DU PLAYER HTML5
# =============================================================================

create_html5_player() {
    log_info "Création du player HTML5..."
    
    # Créer la structure
    mkdir -p "$PLAYER_DIR"/{css,js,api}
    
    # Page principale du player
    cat > "$PLAYER_DIR/player.html" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage Player</title>
    <link rel="stylesheet" href="css/player.css">
</head>
<body>
    <div id="player-container">
        <video id="video-player" autoplay muted></video>
        <div id="no-content" class="hidden">
            <div class="no-content-message">
                <h1>📺 Pi Signage</h1>
                <p>En attente de contenu...</p>
                <p class="hint">Ajoutez des vidéos via l'interface web</p>
            </div>
        </div>
        <div id="overlay" class="hidden">
            <div class="video-info">
                <span id="video-title"></span>
            </div>
        </div>
    </div>
    
    <div id="debug-panel" class="hidden">
        <h3>Debug Info</h3>
        <pre id="debug-info"></pre>
    </div>
    
    <script src="js/player.js"></script>
</body>
</html>
EOF

    # CSS du player
    cat > "$PLAYER_DIR/css/player.css" << 'EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    background: #000;
    overflow: hidden;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

#player-container {
    width: 100vw;
    height: 100vh;
    position: relative;
}

#video-player {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

#no-content {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
}

.no-content-message {
    text-align: center;
    color: white;
}

.no-content-message h1 {
    font-size: 4rem;
    margin-bottom: 1rem;
    font-weight: 300;
}

.no-content-message p {
    font-size: 1.5rem;
    margin-bottom: 0.5rem;
}

.no-content-message .hint {
    font-size: 1rem;
    opacity: 0.7;
}

#overlay {
    position: absolute;
    bottom: 30px;
    left: 30px;
    background: rgba(0, 0, 0, 0.8);
    padding: 15px 25px;
    border-radius: 8px;
    backdrop-filter: blur(10px);
}

.video-info {
    color: white;
    font-size: 1.2rem;
}

.hidden {
    display: none !important;
}

#debug-panel {
    position: absolute;
    top: 10px;
    right: 10px;
    background: rgba(0, 0, 0, 0.9);
    color: #0f0;
    padding: 10px;
    font-family: monospace;
    font-size: 12px;
    max-width: 300px;
    border-radius: 4px;
}

/* Animations */
@keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
}

#overlay {
    animation: fadeIn 0.5s ease-in-out;
}
EOF

    # JavaScript du player
    cat > "$PLAYER_DIR/js/player.js" << 'EOF'
/**
 * Pi Signage HTML5 Player
 */

class PiSignagePlayer {
    constructor() {
        this.player = document.getElementById('video-player');
        this.noContent = document.getElementById('no-content');
        this.overlay = document.getElementById('overlay');
        this.videoTitle = document.getElementById('video-title');
        this.debugPanel = document.getElementById('debug-panel');
        this.debugInfo = document.getElementById('debug-info');
        
        this.playlist = [];
        this.currentIndex = 0;
        this.retryCount = 0;
        this.maxRetries = 3;
        this.overlayTimeout = null;
        
        // Configuration
        this.config = {
            playlistUrl: '/api/playlist.json',
            statusUrl: '/api/status.json',
            websocketUrl: 'ws://localhost:8889',
            overlayDuration: 5000,
            retryDelay: 5000,
            debugMode: false
        };
        
        this.init();
    }
    
    async init() {
        console.log('Pi Signage Player initializing...');
        
        // Charger la playlist
        await this.loadPlaylist();
        
        // Configurer les événements
        this.setupEventListeners();
        
        // Démarrer la lecture
        this.play();
        
        // Connexion WebSocket pour contrôle temps réel
        this.connectWebSocket();
        
        // Activer le mode debug avec Ctrl+D
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'd') {
                this.toggleDebug();
            }
        });
        
        // Mise à jour périodique de la playlist
        setInterval(() => this.loadPlaylist(), 60000);
    }
    
    async loadPlaylist() {
        try {
            const response = await fetch(this.config.playlistUrl);
            if (response.ok) {
                const data = await response.json();
                this.playlist = data.videos || [];
                this.updateDebug(`Playlist loaded: ${this.playlist.length} videos`);
                
                if (this.playlist.length === 0) {
                    this.showNoContent();
                }
            } else {
                throw new Error(`HTTP ${response.status}`);
            }
        } catch (error) {
            console.error('Failed to load playlist:', error);
            this.updateDebug(`Playlist error: ${error.message}`);
            
            // Fallback: chercher dans le dossier vidéos local
            this.playlist = [
                { path: '/videos/sample.mp4', name: 'Sample Video' }
            ];
        }
    }
    
    setupEventListeners() {
        // Vidéo terminée
        this.player.addEventListener('ended', () => {
            this.next();
        });
        
        // Erreur de lecture
        this.player.addEventListener('error', (e) => {
            console.error('Video error:', e);
            this.handleError();
        });
        
        // Vidéo chargée
        this.player.addEventListener('loadedmetadata', () => {
            this.retryCount = 0;
            this.showOverlay();
        });
        
        // Lecture démarrée
        this.player.addEventListener('playing', () => {
            this.noContent.classList.add('hidden');
        });
    }
    
    play() {
        if (this.playlist.length === 0) {
            this.showNoContent();
            return;
        }
        
        const video = this.playlist[this.currentIndex];
        this.updateDebug(`Playing: ${video.name}`);
        
        this.player.src = video.path;
        this.videoTitle.textContent = video.name || 'Sans titre';
        
        // Forcer la lecture
        const playPromise = this.player.play();
        if (playPromise !== undefined) {
            playPromise.catch(error => {
                console.error('Autoplay failed:', error);
                // Réessayer avec son coupé
                this.player.muted = true;
                this.player.play();
            });
        }
    }
    
    next() {
        this.currentIndex = (this.currentIndex + 1) % this.playlist.length;
        this.play();
    }
    
    previous() {
        this.currentIndex = (this.currentIndex - 1 + this.playlist.length) % this.playlist.length;
        this.play();
    }
    
    handleError() {
        this.retryCount++;
        this.updateDebug(`Error loading video, retry ${this.retryCount}/${this.maxRetries}`);
        
        if (this.retryCount < this.maxRetries) {
            setTimeout(() => this.play(), this.config.retryDelay);
        } else {
            // Passer à la vidéo suivante
            this.retryCount = 0;
            this.next();
        }
    }
    
    showNoContent() {
        this.noContent.classList.remove('hidden');
        this.player.classList.add('hidden');
    }
    
    showOverlay() {
        this.overlay.classList.remove('hidden');
        
        // Masquer après quelques secondes
        clearTimeout(this.overlayTimeout);
        this.overlayTimeout = setTimeout(() => {
            this.overlay.classList.add('hidden');
        }, this.config.overlayDuration);
    }
    
    connectWebSocket() {
        try {
            this.ws = new WebSocket(this.config.websocketUrl);
            
            this.ws.onopen = () => {
                console.log('WebSocket connected');
                this.updateDebug('WebSocket: connected');
            };
            
            this.ws.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    this.handleWebSocketMessage(message);
                } catch (error) {
                    console.error('WebSocket message error:', error);
                }
            };
            
            this.ws.onclose = () => {
                console.log('WebSocket disconnected, reconnecting...');
                this.updateDebug('WebSocket: disconnected');
                setTimeout(() => this.connectWebSocket(), 5000);
            };
            
            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
        } catch (error) {
            console.error('WebSocket connection failed:', error);
            this.updateDebug('WebSocket: failed to connect');
        }
    }
    
    handleWebSocketMessage(message) {
        this.updateDebug(`WS message: ${message.command}`);
        
        switch (message.command) {
            case 'play':
                this.player.play();
                break;
            case 'pause':
                this.player.pause();
                break;
            case 'next':
                this.next();
                break;
            case 'previous':
                this.previous();
                break;
            case 'reload':
                location.reload();
                break;
            case 'update_playlist':
                this.loadPlaylist();
                break;
            default:
                console.warn('Unknown command:', message.command);
        }
    }
    
    toggleDebug() {
        this.config.debugMode = !this.config.debugMode;
        this.debugPanel.classList.toggle('hidden');
    }
    
    updateDebug(message) {
        if (this.config.debugMode) {
            const timestamp = new Date().toLocaleTimeString();
            this.debugInfo.textContent = `${timestamp} - ${message}\n${this.debugInfo.textContent}`;
            
            // Limiter le nombre de lignes
            const lines = this.debugInfo.textContent.split('\n');
            if (lines.length > 20) {
                this.debugInfo.textContent = lines.slice(0, 20).join('\n');
            }
        }
    }
}

// Démarrer quand le DOM est prêt
document.addEventListener('DOMContentLoaded', () => {
    window.player = new PiSignagePlayer();
});

// Empêcher le menu contextuel
document.addEventListener('contextmenu', (e) => e.preventDefault());
EOF

    # API de playlist (exemple)
    cat > "$PLAYER_DIR/api/playlist.json" << 'EOF'
{
    "version": "1.0",
    "updated": "2024-01-20T12:00:00Z",
    "videos": []
}
EOF

    # Configuration nginx pour servir le player
    cat > "/etc/nginx/sites-available/pi-signage-player" << 'EOF'
server {
    listen 8888;
    listen [::]:8888;
    
    server_name _;
    root /var/www/pi-signage-player;
    index player.html;
    
    # Logs
    access_log /var/log/nginx/player-access.log;
    error_log /var/log/nginx/player-error.log;
    
    # Sécurité basique
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    
    # Vidéos depuis /opt/videos
    location /videos/ {
        alias /opt/videos/;
        autoindex off;
    }
    
    # API
    location /api/ {
        default_type application/json;
    }
    
    # Cache pour les assets
    location ~* \.(css|js|jpg|jpeg|png|gif|ico)$ {
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Activer le site
    ln -sf /etc/nginx/sites-available/pi-signage-player /etc/nginx/sites-enabled/
    
    # Permissions
    secure_dir_permissions "$PLAYER_DIR" "www-data" "www-data" "755"
    
    # Redémarrer nginx
    if nginx -t; then
        systemctl restart nginx
        log_info "Player HTML5 créé et configuré"
    else
        log_error "Configuration nginx invalide"
        return 1
    fi
}

# =============================================================================
# CRÉATION DU SERVICE SYSTEMD
# =============================================================================

create_systemd_service() {
    log_info "Création du service systemd..."
    
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Chromium Kiosk Mode for Pi Signage
After=network.target

[Service]
Type=simple
User=pi
Group=pi
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/pi/.Xauthority"
Environment="HOME=/home/pi"

# Script de démarrage
ExecStartPre=/bin/sleep 10
ExecStart=/opt/scripts/chromium-kiosk.sh

# Redémarrage automatique
Restart=always
RestartSec=10

# Logs
StandardOutput=journal
StandardError=journal

# Limites ressources (ajuster selon le Pi)
MemoryMax=512M
CPUQuota=80%

# Kill timeout
TimeoutStopSec=30
KillMode=mixed

[Install]
WantedBy=graphical.target
EOF

    # Recharger systemd et activer le service
    systemctl daemon-reload
    
    if systemctl enable chromium-kiosk.service; then
        log_info "Service Chromium Kiosk activé"
    else
        log_error "Échec de l'activation du service"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION DE DÉMARRAGE X11 MINIMAL
# =============================================================================

configure_x11_minimal() {
    log_info "Configuration de X11 minimal..."
    
    # Créer .xinitrc pour l'utilisateur pi
    cat > "/home/pi/.xinitrc" << 'EOF'
#!/bin/sh

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Démarrer Chromium Kiosk
exec /opt/scripts/chromium-kiosk.sh
EOF

    chown pi:pi /home/pi/.xinitrc
    chmod +x /home/pi/.xinitrc
    
    # Script de démarrage automatique
    cat > "/opt/scripts/start-x11-kiosk.sh" << 'EOF'
#!/bin/bash

# Attendre que le système soit prêt
sleep 10

# Démarrer X11 avec Chromium
su - pi -c "startx -- -nocursor" &

exit 0
EOF

    chmod +x /opt/scripts/start-x11-kiosk.sh
    
    # Service pour démarrer X11 au boot
    cat > "/etc/systemd/system/x11-kiosk.service" << 'EOF'
[Unit]
Description=X11 Kiosk Mode
After=multi-user.target

[Service]
Type=forking
ExecStart=/opt/scripts/start-x11-kiosk.sh
Restart=on-failure
RestartSec=30

[Install]
WantedBy=graphical.target
EOF

    systemctl daemon-reload
    systemctl enable x11-kiosk.service
    
    log_info "X11 minimal configuré"
}

# =============================================================================
# OPTIMISATIONS CHROMIUM
# =============================================================================

optimize_chromium() {
    log_info "Application des optimisations Chromium..."
    
    # Préférences Chromium pour réduire l'utilisation mémoire
    local prefs_dir="/home/pi/.config/chromium/Default"
    mkdir -p "$prefs_dir"
    
    cat > "$prefs_dir/Preferences" << 'EOF'
{
    "profile": {
        "default_content_setting_values": {
            "plugins": 2,
            "popups": 2,
            "geolocation": 2,
            "notifications": 2,
            "media_stream": 2
        }
    },
    "webkit": {
        "webprefs": {
            "javascript_enabled": true,
            "loads_images_automatically": true,
            "plugins_enabled": false
        }
    }
}
EOF

    chown -R pi:pi /home/pi/.config
    
    # Configuration GPU selon le modèle de Pi
    case "${PI_MODEL:-unknown}" in
        "3B+")
            # Pi 3B+ : optimisations conservatrices
            echo "gpu_mem=128" >> /boot/config.txt
            ;;
        "4B"|"5")
            # Pi 4/5 : utiliser le GPU
            echo "gpu_mem=256" >> /boot/config.txt
            echo "dtoverlay=vc4-fkms-v3d" >> /boot/config.txt
            ;;
    esac
    
    log_info "Optimisations appliquées"
}

# =============================================================================
# SCRIPTS D'ADMINISTRATION
# =============================================================================

create_admin_scripts() {
    log_info "Création des scripts d'administration..."
    
    # Script de contrôle du player
    cat > "/opt/scripts/player-control.sh" << 'EOF'
#!/bin/bash

# Contrôle du player Chromium Kiosk

case "$1" in
    play|pause|next|previous|reload)
        echo "{\"command\":\"$1\"}" | nc -w 1 localhost 8889
        echo "Commande envoyée: $1"
        ;;
    status)
        systemctl status chromium-kiosk
        ;;
    logs)
        tail -f /var/log/pi-signage/chromium.log
        ;;
    restart)
        systemctl restart chromium-kiosk
        ;;
    *)
        echo "Usage: $0 {play|pause|next|previous|reload|status|logs|restart}"
        exit 1
        ;;
esac
EOF

    chmod +x /opt/scripts/player-control.sh
    
    # Script de mise à jour de la playlist
    cat > "/opt/scripts/update-playlist.sh" << 'EOF'
#!/bin/bash

# Mise à jour de la playlist depuis le dossier vidéos

set -euo pipefail

VIDEOS_DIR="/opt/videos"
PLAYLIST_FILE="/var/www/pi-signage-player/api/playlist.json"
LOG_FILE="/var/log/pi-signage/playlist-update.log"

# Créer le répertoire de logs
mkdir -p "$(dirname "$LOG_FILE")"

# Logger
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" >> "$LOG_FILE"
}

log_info "Début de la mise à jour de la playlist"

# Vérifier que le répertoire vidéos existe
if [[ ! -d "$VIDEOS_DIR" ]]; then
    log_info "Répertoire vidéos introuvable: $VIDEOS_DIR"
    exit 1
fi

# Vérifier que jq est installé
if ! command -v jq >/dev/null 2>&1; then
    log_info "jq n'est pas installé"
    exit 1
fi

# Trouver toutes les vidéos (y compris .mkv)
videos=()
video_count=0

while IFS= read -r -d '' file; do
    basename=$(basename "$file")
    videos+=("{\"path\":\"/videos/$basename\",\"name\":\"$basename\"}")
    ((video_count++))
done < <(find "$VIDEOS_DIR" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mov" -o -name "*.mkv" \) -print0 | sort -z)

log_info "Trouvé $video_count vidéo(s)"

# Créer le JSON
json="{\"version\":\"1.0\",\"updated\":\"$(date -Iseconds)\",\"videos\":["

# Joindre les vidéos avec des virgules
if [[ ${#videos[@]} -gt 0 ]]; then
    json+=$(IFS=,; echo "${videos[*]}")
fi

json+="]}"

# Créer le répertoire de destination si nécessaire
playlist_dir=$(dirname "$PLAYLIST_FILE")
if [[ ! -d "$playlist_dir" ]]; then
    mkdir -p "$playlist_dir"
    chown -R www-data:www-data "$playlist_dir"
fi

# Écrire la playlist
echo "$json" | jq '.' > "$PLAYLIST_FILE"
chown www-data:www-data "$PLAYLIST_FILE"
chmod 644 "$PLAYLIST_FILE"

log_info "Playlist mise à jour: $video_count vidéos"

# Notifier le player via WebSocket
if systemctl is-active --quiet chromium-kiosk.service; then
    echo '{"command":"update_playlist"}' | nc -w 1 localhost 8889 2>/dev/null || true
fi

exit 0
EOF

    chmod +x /opt/scripts/update-playlist.sh
    
    # Ajouter un cron pour mise à jour automatique
    echo "*/5 * * * * root /opt/scripts/update-playlist.sh" > /etc/cron.d/pi-signage-playlist
    
    log_info "Scripts d'administration créés"
}

# =============================================================================
# COMPATIBILITÉ YOUTUBE
# =============================================================================

ensure_youtube_compatibility() {
    log_info "Configuration de la compatibilité YouTube..."
    
    # Vérifier si le patch existe
    local patch_script="$SCRIPT_DIR/patches/youtube-chromium-compatibility.sh"
    
    if [[ -f "$patch_script" ]]; then
        log_info "Application du patch de compatibilité YouTube..."
        if bash "$patch_script"; then
            log_info "Patch YouTube appliqué avec succès"
        else
            log_warn "Échec du patch YouTube, les vidéos devront être converties manuellement"
        fi
    else
        log_warn "Patch YouTube non trouvé, création d'un wrapper basique..."
        
        # Créer un wrapper basique
        cat > /usr/local/bin/yt-dlp-chromium << 'EOF'
#!/bin/bash
# Wrapper basique pour forcer MP4/H.264
exec yt-dlp -f "best[ext=mp4]/best" --merge-output-format mp4 "$@"
EOF
        chmod +x /usr/local/bin/yt-dlp-chromium
    fi
}

# =============================================================================
# VALIDATION DE L'INSTALLATION
# =============================================================================

validate_installation() {
    log_info "Validation de l'installation Chromium Kiosk..."
    
    local errors=0
    
    # Vérification de Chromium
    if command -v chromium-browser >/dev/null 2>&1; then
        log_info "✓ Chromium installé"
    else
        log_error "✗ Chromium manquant"
        ((errors++))
    fi
    
    # Vérification des scripts
    if [[ -f "$KIOSK_SCRIPT" && -x "$KIOSK_SCRIPT" ]]; then
        log_info "✓ Script kiosk créé"
    else
        log_error "✗ Script kiosk manquant"
        ((errors++))
    fi
    
    # Vérification du player HTML5
    if [[ -f "$PLAYER_DIR/player.html" ]]; then
        log_info "✓ Player HTML5 déployé"
    else
        log_error "✗ Player HTML5 manquant"
        ((errors++))
    fi
    
    # Vérification du service
    if systemctl is-enabled chromium-kiosk.service >/dev/null 2>&1; then
        log_info "✓ Service systemd activé"
    else
        log_error "✗ Service systemd non activé"
        ((errors++))
    fi
    
    # Vérification nginx
    if nginx -t 2>/dev/null; then
        log_info "✓ Configuration nginx valide"
    else
        log_error "✗ Configuration nginx invalide"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Installation Chromium Kiosk ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes d'installation
    local steps=(
        "install_chromium"
        "create_kiosk_script"
        "create_html5_player"
        "create_systemd_service"
        "configure_x11_minimal"
        "optimize_chromium"
        "create_admin_scripts"
        "ensure_youtube_compatibility"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        log_info "Exécution: $step"
        if ! "$step"; then
            log_error "Échec de l'étape: $step"
            failed_steps+=("$step")
        fi
    done
    
    # Validation
    if validate_installation; then
        log_info "Chromium Kiosk installé avec succès"
        log_info ""
        log_info "Player accessible sur: http://localhost:8888/player.html"
        log_info "Contrôle: /opt/scripts/player-control.sh {play|pause|next|...}"
        log_info "Mise à jour playlist: /opt/scripts/update-playlist.sh"
    else
        log_warn "Installation terminée avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation Chromium Kiosk ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Enregistrer le mode d'affichage
echo "DISPLAY_MODE=chromium" >> "$CONFIG_FILE"

main "$@"