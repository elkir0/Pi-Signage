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
    # Initialiser et nettoyer dpkg si nécessaire
    init_dpkg_cleanup
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
    
    # Charger aussi l'environnement graphique détecté
    if [[ -f /tmp/gui-environment.conf ]]; then
        source /tmp/gui-environment.conf
        log_info "Environnement graphique: $GUI_TYPE ($GUI_SESSION)"
    fi
}

# =============================================================================
# INSTALLATION DE CHROMIUM
# =============================================================================

install_chromium() {
    log_info "Installation de Chromium..."
    
    # Paquets nécessaires pour Chromium kiosk
    # IMPORTANT: Installer d'abord les dépendances GTK pour éviter les problèmes
    local packages=(
        "libgtk-3-common"   # Dépendance critique à installer en premier
        "libgtk-3-0"        # Requis pour Chromium
        "chromium-browser"
        "nginx"  # Pour servir le player local
        "unclutter"  # Pour masquer le curseur de la souris
    )
    
    # Charger la configuration pour obtenir le serveur d'affichage
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    # Ajouter seatd si on utilise Wayland
    if [[ "${DISPLAY_SERVER:-}" == "wayland" ]]; then
        packages+=("seatd")
        log_info "Ajout de seatd pour support Wayland"
    fi
    
    # Ajouter les paquets X11 seulement si pas d'environnement graphique existant
    local has_gui="${HAS_GUI:-false}"
    if [[ $has_gui != true ]] && ! dpkg -l xserver-xorg-core >/dev/null 2>&1; then
        packages+=(
            "xserver-xorg-core"
            "xserver-xorg-video-fbdev"
            "xinit"
            "x11-xserver-utils"
            "unclutter"
        )
        log_info "Ajout des paquets X11 (pas d'interface graphique détectée)"
    else
        log_info "Interface graphique existante, utilisation de l'environnement actuel"
    fi
    
    # Détection VM et ajout xvfb si nécessaire
    if [[ -f /etc/pi-signage/vm-mode.conf ]] || ! [[ -f /proc/device-tree/model ]]; then
        log_info "Mode VM détecté, ajout de Xvfb pour display virtuel"
        packages+=("xvfb")
    fi
    
    # Mise à jour des listes de paquets
    log_info "Mise à jour des listes de paquets..."
    safe_execute "apt-get update" 2 5
    
    # Réparer les dépendances cassées si nécessaire
    if ! dpkg --audit >/dev/null 2>&1; then
        log_warn "Dépendances cassées détectées, réparation..."
        safe_execute "apt-get install -f -y" 2 10
    fi
    
    # Utiliser la fonction robuste d'installation
    if safe_apt_install "${packages[@]}"; then
        log_info "Chromium et dépendances installés avec succès"
    else
        # Si chromium-browser échoue, essayer chromium
        log_warn "Tentative avec le paquet 'chromium' au lieu de 'chromium-browser'"
        
        # Retirer chromium-browser et ajouter chromium
        local alt_packages=("${packages[@]}")
        alt_packages[2]="chromium"  # Remplacer chromium-browser par chromium
        
        if safe_apt_install "${alt_packages[@]}"; then
            log_info "Chromium installé avec succès (version alternative)"
        else
            log_error "Échec de l'installation de Chromium"
            return 1
        fi
    fi
    
    # Vérification (chromium-browser ou chromium)
    if command -v chromium-browser >/dev/null 2>&1; then
        local version
        version=$(chromium-browser --version 2>/dev/null || echo "Version inconnue")
        log_info "Chromium disponible: $version"
    elif command -v chromium >/dev/null 2>&1; then
        local version
        version=$(chromium --version 2>/dev/null || echo "Version inconnue")
        log_info "Chromium disponible: $version"
    else
        log_error "Chromium non disponible après installation"
        return 1
    fi
    
    # Configurer les permissions si nécessaire
    configure_permissions
}

# =============================================================================
# CONFIGURATION DES PERMISSIONS
# =============================================================================

configure_permissions() {
    log_info "Configuration des permissions..."
    
    # Ajouter l'utilisateur pi aux groupes nécessaires
    local groups=(video audio input tty)
    
    # Ajouter seat si seatd est installé
    if systemctl list-unit-files seatd.service >/dev/null 2>&1; then
        groups+=(seat)
    fi
    
    for group in "${groups[@]}"; do
        if getent group "$group" >/dev/null; then
            usermod -a -G "$group" pi 2>/dev/null || true
            log_info "Utilisateur pi ajouté au groupe $group"
        fi
    done
    
    # Activer et démarrer seatd si installé (pour Wayland)
    if [[ "${DISPLAY_SERVER:-}" == "wayland" ]] && systemctl list-unit-files seatd.service >/dev/null 2>&1; then
        log_info "Activation de seatd pour Wayland"
        systemctl enable seatd >/dev/null 2>&1 || true
        systemctl start seatd >/dev/null 2>&1 || true
    fi
    
    # Créer les règles udev pour les permissions
    cat > /etc/udev/rules.d/99-kiosk.rules << 'EOF'
# Permissions pour mode kiosk
SUBSYSTEM=="input", GROUP="input", MODE="0664"
SUBSYSTEM=="drm", GROUP="video", MODE="0664"
SUBSYSTEM=="seat", GROUP="seat", MODE="0664"
EOF
    
    # Recharger les règles udev
    udevadm control --reload-rules >/dev/null 2>&1 || true
    
    log_info "Permissions configurées"
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

# Détecter le système d'affichage
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    log_kiosk "Système Wayland détecté"
    IS_WAYLAND=true
    # Variables d'environnement pour Wayland
    export XDG_SESSION_TYPE=wayland
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
else
    log_kiosk "Système X11 détecté"
    IS_WAYLAND=false
    # Variables d'environnement pour X11
    export DISPLAY=:0
    export XAUTHORITY=/home/$USER/.Xauthority
fi

# Créer les répertoires nécessaires
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p /var/cache/chromium-kiosk
chown $USER:$USER /var/cache/chromium-kiosk

# Détecter si on est en mode VM et démarrer Xvfb si nécessaire
if [[ "$IS_WAYLAND" == "false" ]] && ([[ -f /etc/pi-signage/vm-mode.conf ]] || ! [[ -f /proc/device-tree/model ]]); then
    log_kiosk "Mode VM détecté, démarrage de Xvfb"
    # Tuer tout Xvfb existant
    pkill -f Xvfb || true
    # Démarrer Xvfb en arrière-plan
    Xvfb :0 -screen 0 1920x1080x24 &
    XVFB_PID=$!
    sleep 2
    export DISPLAY=:0
fi

# Configuration spécifique X11
if [[ "$IS_WAYLAND" == "false" ]]; then
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

    # Masquer le curseur après 0.1 seconde d'inactivité
    unclutter -idle 0.1 -root &
fi

# Nettoyer les profils Chromium précédents
rm -rf /home/$USER/.cache/chromium
rm -rf /home/$USER/.config/chromium

# Options Chromium de base
CHROMIUM_FLAGS=(
    --noerrdialogs
    --disable-infobars
    --disable-session-crashed-bubble
    --disable-translate
    --no-first-run
    --fast
    --fast-start
    --disable-features=TranslateUI,Translate
    --disable-component-update
    --disk-cache-dir=/tmp/chromium-cache
    --overscroll-history-navigation=0
    --disable-pinch
    --autoplay-policy=no-user-gesture-required
    --window-position=0,0
    --check-for-update-interval=31536000
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-renderer-backgrounding
    --disable-ipc-flooding-protection
    --disable-background-networking
    --enable-features=OverlayScrollbar
    --user-data-dir=/var/cache/chromium-kiosk
    --app-auto-launched
)

# Flags spécifiques selon le système d'affichage
if [[ "$IS_WAYLAND" == "true" ]]; then
    log_kiosk "Configuration des flags Wayland"
    # IMPORTANT: L'ordre est critique pour Wayland
    CHROMIUM_FLAGS=(
        --start-maximized  # DOIT être AVANT --start-fullscreen
        --start-fullscreen
        --kiosk
        --ozone-platform=wayland
        --enable-features=UseOzonePlatform,OverlayScrollbar
        "${CHROMIUM_FLAGS[@]}"
    )
else
    log_kiosk "Configuration des flags X11"
    CHROMIUM_FLAGS=(
        --kiosk
        --start-maximized
        --window-size=1920,1080
        "${CHROMIUM_FLAGS[@]}"
    )
fi

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
        <video id="video-player" autoplay controls></video>
        <div id="play-button" class="hidden" onclick="window.player.startWithSound()">
            <div class="play-icon">▶</div>
            <p>Cliquez pour démarrer avec le son</p>
        </div>
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
    cursor: none !important;
}

* {
    cursor: none !important;
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

#play-button {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: rgba(255, 255, 255, 0.95);
    padding: 40px;
    border-radius: 10px;
    cursor: pointer;
    text-align: center;
    transition: transform 0.2s;
    z-index: 100;
}

#play-button:hover {
    transform: translate(-50%, -50%) scale(1.05);
}

.play-icon {
    font-size: 60px;
    color: #333;
    margin-bottom: 10px;
}

#play-button p {
    color: #333;
    font-size: 16px;
    margin: 0;
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
        
        // Configuration du volume
        this.player.volume = 1.0; // Volume au maximum
        this.player.muted = false; // S'assurer que le son n'est pas coupé
        
        // Forcer la lecture
        const playPromise = this.player.play();
        if (playPromise !== undefined) {
            playPromise.catch(error => {
                console.error('Autoplay failed:', error);
                this.updateDebug('Autoplay bloqué, clic utilisateur requis');
                // Afficher un bouton pour démarrer avec son
                this.showPlayButton();
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
    
    showPlayButton() {
        document.getElementById('play-button').classList.remove('hidden');
    }
    
    hidePlayButton() {
        document.getElementById('play-button').classList.add('hidden');
    }
    
    startWithSound() {
        this.hidePlayButton();
        this.player.muted = false;
        this.player.volume = 1.0;
        this.player.play().then(() => {
            this.updateDebug('Lecture démarrée avec son');
        }).catch(err => {
            console.error('Erreur de lecture:', err);
        });
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

    # Installer nginx si nécessaire
    if ! command -v nginx >/dev/null 2>&1; then
        log_info "Installation de nginx..."
        safe_execute "apt-get install -y nginx" || {
            log_error "Impossible d'installer nginx"
            return 1
        }
    fi
    
    # Créer les répertoires nginx si nécessaire
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    
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
    ln -sf /etc/nginx/sites-available/pi-signage-player /etc/nginx/sites-enabled/pi-signage-player
    
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
    
    # Pour compatibilité, on crée deux services :
    # 1. Service système pour démarrage sans session graphique (headless)
    # 2. Service utilisateur pour démarrage dans session graphique
    
    # Service système (pour headless/X11 minimal)
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Chromium Kiosk Mode for Pi Signage (System)
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

    # Service utilisateur (recommandé pour desktop)
    local user_service_dir="/home/pi/.config/systemd/user"
    mkdir -p "$user_service_dir"
    
    cat > "$user_service_dir/chromium-kiosk.service" << 'EOF'
[Unit]
Description=Chromium Kiosk Mode for Pi Signage (User)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 5
ExecStart=/opt/scripts/chromium-kiosk.sh
Restart=on-failure
RestartSec=5

# Variables d'environnement
Environment="DISPLAY=:0"
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="XDG_RUNTIME_DIR=/run/user/1000"

# Logs
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    chown -R pi:pi "$user_service_dir"
    
    # Recharger systemd
    systemctl daemon-reload
    
    # Déterminer quel service activer selon l'environnement
    local has_gui="${HAS_GUI:-false}"
    local display_server="${DISPLAY_SERVER:-}"
    
    if [[ $has_gui == true ]] && [[ "$display_server" == "wayland" || "${GUI_TYPE:-}" == "lightdm" ]]; then
        # Pour desktop avec session graphique, utiliser le service utilisateur
        log_info "Activation du service utilisateur (recommandé pour desktop)"
        su - pi -c "systemctl --user daemon-reload"
        su - pi -c "systemctl --user enable chromium-kiosk.service"
        
        # Activer linger pour que le service utilisateur démarre au boot
        loginctl enable-linger pi
        
        log_info "Service utilisateur Chromium Kiosk activé"
        log_info "Note: Le service démarrera avec la session graphique de l'utilisateur pi"
    else
        # Pour headless ou X11 minimal, utiliser le service système
        log_info "Activation du service système (mode headless/X11 minimal)"
        if systemctl enable chromium-kiosk.service; then
            log_info "Service système Chromium Kiosk activé"
        else
            log_error "Échec de l'activation du service"
            return 1
        fi
    fi
}

# =============================================================================
# CONFIGURATION DE DÉMARRAGE SELON L'ENVIRONNEMENT
# =============================================================================

configure_autostart() {
    log_info "Configuration du démarrage automatique..."
    
    # Charger la configuration pour obtenir les variables d'environnement
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    local has_gui="${HAS_GUI:-false}"
    local gui_type="${GUI_TYPE:-none}"
    local gui_session="${GUI_SESSION:-}"
    local compositor="${COMPOSITOR:-}"
    local display_server="${DISPLAY_SERVER:-}"
    
    if [[ $has_gui == true ]]; then
        log_info "Configuration pour environnement graphique existant:"
        log_info "  - Type: $gui_type"
        log_info "  - Serveur: $display_server"
        log_info "  - Compositeur: $compositor"
        
        # Configuration selon le serveur d'affichage et compositeur
        if [[ "$display_server" == "wayland" ]]; then
            case "$compositor" in
                "labwc")
                    configure_labwc_autostart
                    ;;
                "wayfire")
                    configure_wayfire_autostart
                    ;;
                *)
                    log_warn "Compositeur Wayland non reconnu: $compositor"
                    configure_generic_autostart
                    ;;
            esac
        else
            # Configuration X11
            case "$gui_type" in
                "lightdm")
                    configure_lightdm_autostart
                    ;;
                "raspberrypi-desktop")
                    # Raspberry Pi Desktop peut être X11 ou Wayland
                    if [[ "$display_server" == "wayland" ]]; then
                        if [[ "$compositor" == "labwc" ]]; then
                            configure_labwc_autostart
                        else
                            configure_wayfire_autostart
                        fi
                    else
                        configure_lightdm_autostart
                    fi
                    ;;
                "gdm3"|"sddm")
                    configure_generic_autostart
                    ;;
                "startx")
                    configure_x11_minimal
                    ;;
                *)
                    log_warn "Type d'interface non reconnu, utilisation de la configuration générique"
                    configure_generic_autostart
                    ;;
            esac
        fi
    else
        log_info "Pas d'interface graphique, installation X11 minimal"
        configure_x11_minimal
    fi
}

# Fonction pour configurer l'autologin via raspi-config
configure_pi_autologin() {
    log_info "Configuration de l'autologin..."
    
    # Vérifier si raspi-config est disponible
    if ! command -v raspi-config >/dev/null 2>&1; then
        log_warn "raspi-config non disponible, configuration manuelle"
        configure_pi_autologin_manual
        return
    fi
    
    # Vérifier l'autologin existant d'abord
    local existing_user=""
    local autologin_configured=false
    
    # Pour LightDM
    if [[ -f /etc/lightdm/lightdm.conf ]]; then
        if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf; then
            existing_user=$(grep "^autologin-user=" /etc/lightdm/lightdm.conf | cut -d'=' -f2)
            log_info "Autologin déjà configuré pour: $existing_user"
            autologin_configured=true
        fi
    fi
    
    # Si pas d'autologin configuré, utiliser raspi-config
    if [[ $autologin_configured == false ]]; then
        log_info "Configuration de l'autologin via raspi-config..."
        # B4 = Desktop Autologin
        raspi-config nonint do_boot_behaviour B4
        if [[ $? -eq 0 ]]; then
            log_info "Autologin configuré avec succès via raspi-config"
        else
            log_warn "Échec de raspi-config, tentative de configuration manuelle"
            configure_pi_autologin_manual
        fi
    else
        log_info "Autologin déjà configuré, préservation de la configuration existante"
    fi
}

# Fonction de fallback pour configuration manuelle
configure_pi_autologin_manual() {
    log_info "Configuration manuelle de l'autologin..."
    
    local autologin_configured=false
    local existing_user=""
    
    # Pour LightDM - VÉRIFIER SANS MODIFIER si déjà configuré
    if [[ -f /etc/lightdm/lightdm.conf ]]; then
        # Vérifier si un autologin est déjà configuré
        if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf; then
            existing_user=$(grep "^autologin-user=" /etc/lightdm/lightdm.conf | cut -d'=' -f2)
            log_info "Autologin déjà configuré pour: $existing_user"
            autologin_configured=true
            
            # Si c'est pas l'utilisateur pi, on demande
            if [[ "$existing_user" != "pi" ]]; then
                log_warn "L'autologin est configuré pour '$existing_user', pas 'pi'"
                log_warn "Pi Signage utilisera l'utilisateur '$existing_user' au lieu de 'pi'"
                # On adapte notre configuration pour utiliser cet utilisateur
                echo "KIOSK_USER=$existing_user" >> /tmp/kiosk-user.conf
            fi
        else
            # Seulement si PAS déjà configuré
            log_info "Configuration de l'autologin pour pi..."
            sed -i 's/#autologin-user=/autologin-user=pi/g' /etc/lightdm/lightdm.conf
            sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf
        fi
    fi
    
    # Pour GDM3 - VÉRIFIER SANS MODIFIER si déjà configuré
    if [[ -f /etc/gdm3/custom.conf ]]; then
        if grep -q "AutomaticLoginEnable=true" /etc/gdm3/custom.conf; then
            existing_user=$(grep "AutomaticLogin=" /etc/gdm3/custom.conf | cut -d'=' -f2)
            log_info "Autologin GDM3 déjà configuré pour: $existing_user"
            autologin_configured=true
            if [[ "$existing_user" != "pi" ]]; then
                echo "KIOSK_USER=$existing_user" >> /tmp/kiosk-user.conf
            fi
        else
            # Seulement si PAS déjà configuré
            sed -i '/\[daemon\]/a\AutomaticLoginEnable=true\nAutomaticLogin=pi' /etc/gdm3/custom.conf
            log_info "Autologin configuré pour GDM3"
        fi
    fi
    
    # Pour SDDM
    if [[ -d /etc/sddm.conf.d ]]; then
        if [[ ! -f /etc/sddm.conf.d/autologin.conf ]]; then
            cat > /etc/sddm.conf.d/autologin.conf << 'EOF'
[Autologin]
User=pi
Session=plasma
EOF
            log_info "Autologin configuré pour SDDM"
        fi
    fi
    
    # Pour Raspberry Pi Imager / raspi-config autologin
    # Vérifier si configuré via raspi-config (Bookworm)
    if [[ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]]; then
        if grep -q "autologin" /etc/systemd/system/getty@tty1.service.d/autologin.conf; then
            existing_user=$(grep -oP 'autologin \K\w+' /etc/systemd/system/getty@tty1.service.d/autologin.conf || echo "")
            if [[ -n "$existing_user" ]]; then
                log_info "Autologin console déjà configuré pour: $existing_user"
                autologin_configured=true
                if [[ "$existing_user" != "pi" ]]; then
                    echo "KIOSK_USER=$existing_user" >> /tmp/kiosk-user.conf
                fi
            fi
        fi
    fi
    
    # Si vraiment aucun autologin n'est configuré nulle part
    if [[ $autologin_configured == false ]]; then
        log_warn "Aucun autologin détecté. Configuration pour l'utilisateur pi..."
        # Seulement si on a LightDM
        if [[ -f /etc/lightdm/lightdm.conf ]]; then
            sed -i 's/#autologin-user=/autologin-user=pi/g' /etc/lightdm/lightdm.conf
            sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/g' /etc/lightdm/lightdm.conf
        fi
    fi
}

# Configuration pour LightDM (Raspberry Pi OS classique)
configure_lightdm_autostart() {
    log_info "Configuration de l'autostart pour LightDM..."
    
    # Configurer l'autologin
    configure_pi_autologin
    
    # Créer le fichier autostart pour LXDE
    mkdir -p /home/pi/.config/lxsession/LXDE-pi
    cat > /home/pi/.config/lxsession/LXDE-pi/autostart << 'EOF'
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver -no-splash
@point-rpi
@xset s off
@xset -dpms
@xset s noblank
@/opt/scripts/chromium-kiosk.sh
EOF
    
    chown -R pi:pi /home/pi/.config
}

# Configuration pour labwc (nouveau compositeur Wayland par défaut sur Bookworm)
configure_labwc_autostart() {
    log_info "Configuration de l'autostart pour labwc (Wayland)..."
    
    # Configurer l'autologin via raspi-config
    configure_pi_autologin
    
    # Créer le répertoire de configuration labwc
    mkdir -p /etc/xdg/labwc
    
    # Créer le script autostart pour labwc
    cat > /etc/xdg/labwc/autostart << 'EOF'
#!/bin/sh
# labwc autostart pour Pi Signage Chromium Kiosk

# Désactiver les composants desktop non nécessaires
/usr/bin/kanshi &
/usr/bin/lxsession-xdg-autostart &

# Attendre que le système soit prêt
sleep 5

# Lancer Chromium en mode kiosk
/opt/scripts/chromium-kiosk.sh &
EOF
    
    chmod +x /etc/xdg/labwc/autostart
    
    log_info "Configuration labwc terminée"
}

# Configuration pour Wayfire (compositeur Wayland précédent)
configure_wayfire_autostart() {
    log_info "Configuration de l'autostart pour Wayfire (Wayland)..."
    
    # Configurer l'autologin
    configure_pi_autologin
    
    # Configuration Wayfire pour l'utilisateur
    mkdir -p /home/pi/.config
    
    # Créer ou mettre à jour wayfire.ini
    cat > /home/pi/.config/wayfire.ini << 'EOF'
[core]
plugins = autostart idle

[autostart]
# Désactiver les composants non nécessaires
autostart_wf_shell = false
panel = false
background = false
screensaver = false
dpms = false

# Lancer Chromium Kiosk
chromium_kiosk = /opt/scripts/chromium-kiosk.sh

[idle]
# Désactiver l'économiseur d'écran
screensaver_timeout = 0
dpms_timeout = 0
EOF
    
    chown pi:pi /home/pi/.config/wayfire.ini
    
    log_info "Configuration Wayfire terminée"
}

# Configuration pour Raspberry Pi OS Desktop moderne (Wayfire/Wayland)
configure_raspberrypi_desktop_autostart() {
    log_info "Configuration de l'autostart pour Raspberry Pi Desktop (Wayfire)..."
    
    # Configurer l'autologin pour Raspberry Pi Desktop
    configure_pi_autologin
    
    # Créer le répertoire autostart
    mkdir -p /home/pi/.config/autostart
    
    # Créer le fichier .desktop pour démarrage automatique
    cat > /home/pi/.config/autostart/chromium-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Chromium Kiosk
Exec=/opt/scripts/chromium-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
EOF
    
    chmod +x /home/pi/.config/autostart/chromium-kiosk.desktop
    chown -R pi:pi /home/pi/.config
    
    # Désactiver l'économiseur d'écran pour Wayfire
    if [[ -f /home/pi/.config/wayfire.ini ]]; then
        if ! grep -q "idle" /home/pi/.config/wayfire.ini; then
            echo -e "\n[idle]\ndpms_timeout = 0\nidle_timeout = 0" >> /home/pi/.config/wayfire.ini
        fi
    fi
}

# Configuration générique pour autres environnements
configure_generic_autostart() {
    log_info "Configuration générique de l'autostart..."
    
    # Utiliser systemd user service
    mkdir -p /home/pi/.config/systemd/user
    cat > /home/pi/.config/systemd/user/chromium-kiosk.service << 'EOF'
[Unit]
Description=Chromium Kiosk Mode
After=graphical-session.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 10
ExecStart=/opt/scripts/chromium-kiosk.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
    
    # Activer le service utilisateur
    su - pi -c "systemctl --user enable chromium-kiosk.service"
    
    chown -R pi:pi /home/pi/.config
}

# Configuration X11 minimal (quand pas d'interface graphique)
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
    log_info "Configuration des préférences Chromium..."
    
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
    
    # Pas de modifications GPU - laissons le système avec ses valeurs par défaut
    log_info "Préférences Chromium configurées (pas de modifications GPU)"
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
# CONFIGURATION AUDIO
# =============================================================================

configure_audio() {
    log_info "Configuration de l'audio pour Chromium..."
    
    # Les paquets audio sont déjà installés dans 01-system-config.sh
    # apt-get install -y alsa-utils pulseaudio 2>/dev/null || true
    
    # Configurer le volume par défaut à 85%
    amixer set Master 85% 2>/dev/null || amixer set PCM 85% 2>/dev/null || true
    
    # Ajouter l'utilisateur pi au groupe audio
    usermod -a -G audio pi
    
    # Créer la configuration ALSA pour pi
    cat > /home/pi/.asoundrc << 'EOF'
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
EOF
    
    chown pi:pi /home/pi/.asoundrc
    
    # NE PAS modifier /boot/config.txt - conformément aux exigences
    # L'audio HDMI fonctionne généralement sans hdmi_drive=2
    log_info "Configuration audio terminée (sans modification de boot)"
    
    log_info "Audio configuré pour Chromium"
}

# =============================================================================
# MODE TEST INTÉGRÉ (depuis test-chromium-startup.sh et test-x11-touchscreen.sh)
# =============================================================================

run_chromium_test_mode() {
    log_info "=== MODE TEST CHROMIUM KIOSK ==="
    
    # Arrêter tout ce qui tourne
    log_info "Arrêt des services existants..."
    systemctl stop chromium-kiosk 2>/dev/null || true
    systemctl stop x11-kiosk 2>/dev/null || true
    systemctl stop pi-signage-startup 2>/dev/null || true
    pkill -f chromium 2>/dev/null || true
    pkill -f xinit 2>/dev/null || true
    sleep 2
    
    # Vérifier les prérequis
    log_info "Vérification des prérequis..."
    
    # Mode d'affichage
    if [[ -f /etc/pi-signage/display-mode.conf ]]; then
        local mode
        mode=$(cat /etc/pi-signage/display-mode.conf)
        log_info "✓ Mode configuré: $mode"
    else
        log_warn "Pas de mode configuré, création..."
        mkdir -p /etc/pi-signage
        echo "chromium" > /etc/pi-signage/display-mode.conf
    fi
    
    # Vidéos
    local video_count
    video_count=$(find /opt/videos -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mov" -o -name "*.mkv" \) 2>/dev/null | wc -l)
    if [[ $video_count -gt 0 ]]; then
        log_info "✓ $video_count vidéo(s) trouvée(s)"
    else
        log_warn "⚠ Aucune vidéo dans /opt/videos"
    fi
    
    # Mise à jour de la playlist
    log_info "Mise à jour de la playlist..."
    if [[ -x /opt/scripts/update-playlist.sh ]]; then
        /opt/scripts/update-playlist.sh
        log_info "✓ Playlist mise à jour"
    else
        log_error "Script update-playlist.sh non trouvé"
    fi
    
    # Menu de test
    echo ""
    echo "Test de démarrage Chromium Kiosk"
    echo "==================================="
    echo "1) Via le boot manager (pi-signage-startup)"
    echo "2) Via x11-kiosk service"
    echo "3) Direct xinit"
    echo "4) Test X11 avec terminal (startx)"
    echo "5) Test écran tactile (si présent)"
    echo "6) Quitter"
    echo ""
    read -p "Choisir la méthode [1-6]: " method
    
    case $method in
        1)
            log_info "Démarrage via boot manager..."
            systemctl start pi-signage-startup
            echo "Attendez 15 secondes..."
            sleep 15
            echo ""
            echo "Statut:"
            systemctl status pi-signage-startup --no-pager
            echo ""
            echo "Logs:"
            tail -n 20 /var/log/pi-signage-startup.log 2>/dev/null || echo "Pas de logs"
            ;;
        
        2)
            log_info "Démarrage via x11-kiosk..."
            systemctl start x11-kiosk
            echo "Attendez 10 secondes..."
            sleep 10
            echo ""
            echo "Statut:"
            systemctl status x11-kiosk --no-pager
            ;;
        
        3)
            log_info "Démarrage direct avec xinit..."
            echo "Chromium va démarrer. Pour quitter: Ctrl+Alt+Backspace"
            sleep 3
            su - pi -c "xinit /opt/scripts/chromium-kiosk.sh -- :0 -nocursor"
            ;;
        
        4)
            log_info "Test X11 simple..."
            # Installation minimale si X11 n'est pas présent
            if ! command -v startx &> /dev/null; then
                log_info "Installation de X11..."
                apt-get update
                apt-get install -y xserver-xorg xinit xterm
            fi
            echo "Pour quitter X11, faites Ctrl+Alt+Backspace ou fermez toutes les fenêtres"
            sleep 3
            startx
            ;;
        
        5)
            log_info "Test écran tactile..."
            test_touchscreen
            ;;
        
        6)
            log_info "Sortie du mode test"
            return 0
            ;;
    esac
    
    echo ""
    echo "=== Vérifications post-démarrage ==="
    echo ""
    
    # Vérifier si X est lancé
    if pgrep -x Xorg > /dev/null; then
        log_info "✓ X11 est en cours d'exécution"
    else
        log_error "✗ X11 n'est pas démarré"
    fi
    
    # Vérifier si Chromium est lancé
    if pgrep -f chromium > /dev/null; then
        log_info "✓ Chromium est en cours d'exécution"
    else
        log_error "✗ Chromium n'est pas démarré"
    fi
    
    # Vérifier nginx
    if systemctl is-active nginx > /dev/null; then
        log_info "✓ Nginx est actif (player sur http://localhost:8888/player.html)"
    else
        log_error "✗ Nginx n'est pas actif"
    fi
    
    echo ""
    echo "Pour voir les logs en temps réel:"
    echo "  tail -f /var/log/pi-signage/chromium.log"
    echo "  journalctl -f"
    echo ""
}

# Fonction de test écran tactile (intégrée depuis test-x11-touchscreen.sh)
test_touchscreen() {
    log_info "Test de l'écran tactile..."
    
    # Vérifier si on est en SSH ou directement sur le Pi
    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        log_warn "Vous êtes en SSH. Ce test doit être exécuté directement sur le Pi"
        log_info "ou utilisez 'export DISPLAY=:0' avant de lancer les commandes X11"
        echo ""
    fi
    
    # Créer un fichier de configuration X11 pour le tactile
    cat > /tmp/99-calibration.conf << 'EOF'
Section "InputClass"
    Identifier "calibration"
    MatchProduct "FT5406 memory based driver"
    Option "TransformationMatrix" "1 0 0 0 1 0 0 0 1"
    Option "SwapAxes" "0"
EndSection
EOF
    
    if [[ -d /etc/X11/xorg.conf.d ]]; then
        cp /tmp/99-calibration.conf /etc/X11/xorg.conf.d/
        log_info "Configuration tactile appliquée"
    fi
    
    # Créer un xinitrc de test
    cat > /tmp/test-xinitrc << 'EOF'
#!/bin/sh
# xinitrc de test pour écran tactile

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Message d'accueil
xmessage -center "X11 fonctionne ! Testez le tactile en cliquant" &

# Lancer Chromium avec une page de test tactile
chromium-browser --kiosk --touch-events=enabled --enable-touch-drag-drop https://www.google.com/maps &

# Garder X11 actif
exec xterm
EOF
    
    chmod +x /tmp/test-xinitrc
    
    echo ""
    echo "Options de test tactile:"
    echo "a) Lancer le test tactile avec Google Maps"
    echo "b) Lancer Chromium Pi Signage avec support tactile"
    echo "c) Instructions manuelles"
    echo ""
    read -p "Votre choix [a-c]: " choice
    
    case $choice in
        a)
            log_info "Lancement du test tactile..."
            echo "Pour quitter, utilisez Alt+F4"
            sleep 3
            xinit /tmp/test-xinitrc -- :0
            ;;
        
        b)
            log_info "Lancement de Pi Signage avec support tactile..."
            # Modifier temporairement le script chromium-kiosk pour activer le tactile
            if [[ -f /opt/scripts/chromium-kiosk.sh ]]; then
                # Ajouter les flags tactiles
                sed -i '/CHROMIUM_FLAGS=(/a\    --touch-events=enabled\n    --enable-touch-drag-drop\n    --touch-devices=1' /opt/scripts/chromium-kiosk.sh
                xinit /opt/scripts/chromium-kiosk.sh -- :0
            else
                log_error "Script chromium-kiosk.sh non trouvé"
            fi
            ;;
        
        c)
            echo ""
            echo "=== Instructions pour tester l'écran tactile ==="
            echo ""
            echo "1. Pour un test basique X11 :"
            echo "   startx"
            echo ""
            echo "2. Pour tester Chromium avec l'écran tactile :"
            echo "   xinit chromium-browser --kiosk --touch-events=enabled http://google.com -- :0"
            echo ""
            echo "3. Configuration tactile :"
            echo "   - L'écran tactile officiel devrait fonctionner automatiquement"
            echo "   - Pour calibrer : sudo apt-get install xinput-calibrator && xinput_calibrator"
            echo ""
            echo "4. Résolution de problèmes :"
            echo "   - Vérifier les logs : journalctl -xe"
            echo "   - Tester le tactile : evtest (choisir FT5406)"
            echo "   - Rotation écran : sudo nano /boot/config.txt"
            echo "     Ajouter : display_rotate=2 (pour 180°)"
            echo ""
            echo "Notes importantes:"
            echo "• L'écran tactile officiel 7\" utilise le driver FT5406"
            echo "• La résolution native est 800x480"
            echo "• Le tactile devrait fonctionner automatiquement avec X11"
            echo "• Support multi-touch limité (single touch principalement)"
            ;;
    esac
    
    rm -f /tmp/test-xinitrc /tmp/99-calibration.conf
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
        "configure_autostart"
        "configure_audio"
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
        
        # Proposer le mode test
        echo ""
        read -p "Voulez-vous lancer le mode test maintenant ? [o/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            run_chromium_test_mode
        fi
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