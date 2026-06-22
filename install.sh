#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║                  PiSignage v0.11.0 - Installation Unifiée            ║
# ║                     Script d'installation ONE-CLICK                   ║
# ║                          Date: 2025-10-01                            ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

# S'exécute en tant que 'pi' (non-root) : /usr/sbin et /sbin ne sont pas toujours dans
# le PATH d'un utilisateur normal sur Debian, or `command -v nginx` (/usr/sbin/nginx)
# en dépend -> sans ça, configure_webserver sautait silencieusement la config nginx.
export PATH="/usr/sbin:/sbin:$PATH"

# Configuration
VERSION="0.11.0"
INSTALL_DIR="/opt/pisignage"
GITHUB_REPO="https://github.com/elkir0/Pi-Signage.git"
BBB_URL="http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonctions d'affichage
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# Detect OS version
detect_os_version() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_VERSION_ID="${VERSION_ID:-unknown}"
        OS_VERSION_CODENAME="${VERSION_CODENAME:-unknown}"
        log_info "Detected OS: ${NAME:-Unknown} ${VERSION_ID:-?} (${VERSION_CODENAME:-?})"

        # Check if Trixie/Debian 13
        if [ "$VERSION_CODENAME" = "trixie" ] || [ "$VERSION_ID" = "13" ]; then
            IS_TRIXIE=1
            # Chromium kiosk = lecteur par défaut sur Trixie ; VLC reste en secours.
            USE_CHROMIUM_PLAYER=1
            log_info "Trixie (Debian 13) detected - Wayland kiosk mode available"

            # Check if Desktop edition (required for Wayland)
            if ! dpkg -l 2>/dev/null | grep -qE "task-desktop|task-gnome|task-lxde|task-xfce"; then
                log_warn "⚠️  WARNING: Raspberry Pi OS Lite detected!"
                log_warn "    Wayland kiosk mode REQUIRES Desktop edition"
                log_warn "    Lite edition lacks critical graphics infrastructure"
                log_warn ""
                log_warn "    Installation will continue, but Wayland features will fail."
                log_warn "    VLC player will still work for basic media playback."
                log_warn ""
                log_warn "    For full Chromium kiosk support, re-flash with:"
                log_warn "    'Raspberry Pi OS with desktop' from raspberrypi.com"
                echo ""
                if [ -z "$AUTO_MODE" ]; then
                    read -p "Continue anyway? (y/N) " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        log_error "Installation aborted by user"
                        exit 1
                    fi
                else
                    log_warn "Auto mode: Continuing despite Desktop requirement warning"
                fi
            else
                log_info "Desktop edition detected - full Wayland support available"
            fi
        else
            IS_TRIXIE=0
            # Pas de Chromium kiosk hors Trixie -> VLC est le lecteur.
            USE_CHROMIUM_PLAYER=0
        fi
    else
        log_warn "Cannot detect OS version (/etc/os-release missing)"
        IS_TRIXIE=0
        USE_CHROMIUM_PLAYER=0
    fi
}

# Vérifier si root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Ce script ne doit pas être exécuté en root"
        log_info "Utilisation: bash install.sh"
        exit 1
    fi
}

# Garde matérielle: cible Raspberry Pi 4/5 (2GB+).
# Calquée sur detect_os_version(): lit /proc/device-tree/model puis, en secours,
# la Revision de /proc/cpuinfo. Ne hard-fail PAS un Compute Module mal classé sans --force.
check_hardware() {
    if [ "${FORCE_INSTALL:-0}" = "1" ]; then
        log_warn "Garde matérielle ignorée (--force)"
        return 0
    fi

    local model=""
    if [ -f /proc/device-tree/model ]; then
        model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
    fi

    # Cas explicites Pi4/Pi5 -> OK.
    case "$model" in
        *"Raspberry Pi 5"*|*"Raspberry Pi 4"*|*"Compute Module 4"*|*"Compute Module 5"*)
            log_info "Matériel détecté: $model"
            return 0
            ;;
    esac

    # Modèles Pi antérieurs explicitement non supportés.
    case "$model" in
        *"Raspberry Pi 3"*|*"Raspberry Pi 2"*|*"Raspberry Pi Model"*|*"Raspberry Pi Zero"*|*"Compute Module 3"*)
            log_error "Modèle détecté: ${model:-inconnu}"
            log_error "PiSignage v${VERSION} requiert un Pi4/5 (2GB+)."
            log_info  "Bypass possible avec --force (non recommandé)."
            exit 1
            ;;
    esac

    # Modèle inconnu / device-tree absent: secours via Revision cpuinfo.
    # On reste tolérant (Compute Module mal classé) -> simple avertissement, pas d'exit.
    if [ -z "$model" ]; then
        local rev=""
        rev=$(grep -m1 -i '^Revision' /proc/cpuinfo 2>/dev/null | awk '{print $NF}')
        log_warn "Modèle Pi indéterminé (Revision='${rev:-?}'). PiSignage cible Pi4/5 (2GB+)."
        log_warn "Poursuite de l'installation (utilisez --force pour supprimer cet avertissement)."
        return 0
    fi

    log_warn "Modèle Pi non reconnu: '$model'. Cible recommandée: Pi4/5 (2GB+). Poursuite."
    return 0
}

# Bannière
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║                    🎬 PiSignage v${VERSION} Installer 🎬                   ║"
    echo "║                                                                      ║"
    echo "║                  Digital Signage pour Raspberry Pi                  ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "Ce script va installer:"
    echo "  • Serveur web (nginx/Apache + PHP)"
    echo "  • VLC (lecteur vidéo)"
    echo "  • Interface web glassmorphisme v${VERSION}"
    echo "  • Big Buck Bunny (vidéo de démo)"
    echo "  • Configuration automatique au démarrage"
    echo ""
    # Mode interactif ou automatique
    if [ "$1" != "--auto" ]; then
        read -p "Appuyez sur Entrée pour commencer l'installation..."
    else
        echo "Mode automatique activé"
    fi
}

# Mise à jour du système
update_system() {
    log_step "Mise à jour du système"
    sudo apt-get update -qq
    # Configuration pour éviter les interactions
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    # Forcer les configurations par défaut pour éviter les blocages
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confold" \
        -o Dpkg::Options::="--force-confdef" || true
    log_info "Système mis à jour"
}

# Installation des dépendances
install_dependencies() {
    log_step "Installation des dépendances"

    # Configuration pour éviter les interactions
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Détection automatique de la version PHP
    PHP_VERSION=""
    if command -v php > /dev/null 2>&1; then
        PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
    fi

    # Dériver depuis /etc/php/ si php absent du PATH au moment de l'install
    if [ -z "$PHP_VERSION" ]; then
        for d in /etc/php/*/fpm; do
            [ -d "$d" ] || continue
            PHP_VERSION=$(basename "$(dirname "$d")")
        done
    fi

    # Dernier recours: laisser apt résoudre le métapaquet php-fpm (pas de version câblée)
    if [ -z "$PHP_VERSION" ]; then
        log_info "Version PHP non détectée, installation du métapaquet php-fpm générique"
    else
        log_info "Version PHP détectée : $PHP_VERSION"
    fi

    # Packages essentiels uniquement
    local packages=(
        "git"
        "nginx"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-cli"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-sqlite3"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-zip"
        "sqlite3"
        "ffmpeg"
        "yt-dlp"
        "xinit"
        "x11-xserver-utils"
        "xserver-xorg"
        "grim"
        "fbgrab"
        "scrot"
        "imagemagick"
        "wget"
        "curl"
        "jq"
        "socat"
    )

    # Trixie-specific packages for Wayland kiosk mode
    # NOTE: chromium n'est PAS dans cette liste — il est installé séparément plus bas
    # (option C) pour ne pas masquer les échecs dans la boucle générique.
    if [ "${IS_TRIXIE:-0}" = "1" ]; then
        log_info "Adding Trixie/Wayland kiosk packages..."
        packages+=(
            "labwc"
            "greetd"
            "plymouth"
        )
    fi

    log_info "Installation des packages essentiels..."
    for package in "${packages[@]}"; do
        echo -n "  • Installation de $package... "
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            -o Dpkg::Options::="--force-confold" \
            -o Dpkg::Options::="--force-confdef" \
            "$package" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠ Déjà installé ou optionnel${NC}"
        fi
    done

    # Installation Chromium (Trixie) — gérée hors boucle pour ne pas masquer les échecs.
    if [ "${IS_TRIXIE:-0}" = "1" ]; then
        log_info "Installation de Chromium (mode kiosk)..."
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser || {
                log_error "Aucun paquet Chromium installable"
                exit 1
            }
        fi

        # Garantir un binaire chromium utilisable et un /usr/bin/chromium canonique.
        CHROMIUM_BIN="$(command -v chromium || command -v chromium-browser || true)"
        [ -z "$CHROMIUM_BIN" ] && [ -x /usr/lib/chromium/chromium ] && CHROMIUM_BIN=/usr/lib/chromium/chromium
        [ -z "$CHROMIUM_BIN" ] && { log_error "Binaire chromium introuvable"; exit 1; }
        # NE PAS créer /usr/bin/chromium s'il existe déjà.
        [ ! -e /usr/bin/chromium ] && sudo ln -sf "$CHROMIUM_BIN" /usr/bin/chromium
        log_info "Chromium prêt ($CHROMIUM_BIN)"

        # Accélération matérielle Pi (best-effort, ne bloque pas l'install).
        sudo apt-get install -y rpi-chromium-mods 2>/dev/null || true
    fi

    # Installation de raspi2png si disponible
    if [ -f /usr/bin/raspi2png ]; then
        log_info "raspi2png déjà installé"
    else
        log_warn "Tentative d'installation de raspi2png..."
        cd /tmp
        if git clone https://github.com/AndrewFromMelbourne/raspi2png.git > /dev/null 2>&1; then
            cd raspi2png
            make > /dev/null 2>&1 && sudo make install > /dev/null 2>&1 || true
            cd /tmp && rm -rf raspi2png
        fi
    fi

    log_info "Toutes les dépendances installées"
}

# Installe un yt-dlp géré par PiSignage : binaire standalone dans /opt/pisignage/bin,
# propriété www-data, donc auto-updatable via `yt-dlp -U` (et depuis l'UI) SANS sudo.
# Le paquet apt yt-dlp ne peut pas se self-update et vieillit vite (échecs de téléchargement).
install_managed_ytdlp() {
    log_step "Installation de yt-dlp géré (auto-updatable)"
    sudo mkdir -p "$INSTALL_DIR/bin"
    if sudo curl -fsSL --max-time 60 \
        https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
        -o "$INSTALL_DIR/bin/yt-dlp" 2>/dev/null; then
        sudo chmod 0755 "$INSTALL_DIR/bin/yt-dlp"
        sudo chown -R www-data:www-data "$INSTALL_DIR/bin"
        log_info "yt-dlp géré installé: $(sudo -u www-data "$INSTALL_DIR/bin/yt-dlp" --version 2>/dev/null || echo 'version inconnue')"
    else
        log_info "ATTENTION: téléchargement de yt-dlp géré échoué — repli sur le paquet apt (mises à jour limitées)"
    fi
}

# Création de la structure de dossiers
create_structure() {
    log_step "Création de la structure PiSignage"

    sudo mkdir -p $INSTALL_DIR/{web,media,config,logs,scripts,backups,data}
    sudo mkdir -p $INSTALL_DIR/web/{api,assets,css,js,screenshots}
    sudo mkdir -p /dev/shm/pisignage-screenshots

    # Créer le répertoire cache pour yt-dlp (BUG-012 fix)
    sudo mkdir -p /var/www/.cache
    sudo chown -R www-data:www-data /var/www/.cache
    sudo chmod 755 /var/www/.cache

    # Permissions élargies pour éviter les problèmes
    sudo chown -R www-data:www-data $INSTALL_DIR
    sudo chmod 755 $INSTALL_DIR
    # Permissions spécifiques pour les répertoires critiques
    sudo chmod 777 $INSTALL_DIR/logs
    sudo chmod 777 $INSTALL_DIR/media
    sudo chmod 755 $INSTALL_DIR/web
    sudo chmod 755 $INSTALL_DIR/scripts
    sudo chmod 755 $INSTALL_DIR/config
    sudo chmod 755 $INSTALL_DIR/data
    sudo chmod 777 $INSTALL_DIR/web/screenshots

    # Initialiser la base de données SQLite
    DB_FILE="$INSTALL_DIR/pisignage.db"
    if [ ! -f "$DB_FILE" ]; then
        log_info "Initialisation de la base de données..."
        sudo sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS media (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    path TEXT NOT NULL,
    type TEXT,
    size INTEGER,
    duration INTEGER,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS playlist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER,
    media_id INTEGER,
    position INTEGER,
    duration INTEGER,
    FOREIGN KEY(playlist_id) REFERENCES playlists(id),
    FOREIGN KEY(media_id) REFERENCES media(id)
);

CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    level TEXT,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
        sudo chmod 666 "$DB_FILE"
        log_info "Base de données initialisée"
    fi

    log_info "Structure créée dans $INSTALL_DIR"
}

# Cloner depuis GitHub
clone_from_github() {
    log_step "Récupération de l'application depuis GitHub"

    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Dépôt Git déjà présent, mise à jour..."
        cd $INSTALL_DIR
        sudo git pull origin main 2>/dev/null || true
    else
        # Cloner le repo complet dans un répertoire temporaire
        log_info "Clonage du dépôt PiSignage depuis GitHub..."
        TEMP_DIR="/tmp/pisignage-clone-$$"
        git clone https://github.com/elkir0/Pi-Signage.git "$TEMP_DIR"

        # Copier tous les fichiers web dans /opt/pisignage
        log_info "Déploiement des fichiers de l'application..."
        sudo cp -r "$TEMP_DIR/web"/* "$INSTALL_DIR/web/" 2>/dev/null || true

        # Déployer les scripts runtime du dépôt (kiosk-apply, screen-power.sh,
        # screen-schedule-tick.sh, grim-capture.sh, screenshot-wayland.sh, rotate-logs.sh…).
        # Certains scripts (start-vlc.sh, autostart.sh) sont (re)générés inline plus loin.
        sudo cp -r "$TEMP_DIR/scripts"/* "$INSTALL_DIR/scripts/" 2>/dev/null || true
        sudo chmod +x "$INSTALL_DIR/scripts/"*.sh "$INSTALL_DIR/scripts/kiosk-apply" 2>/dev/null || true

        # SOURCE OF TRUTH: install.sh GÉNÈRE nginx/php/systemd. On ne copie depuis
        # config/ que la DATA runtime (whitelist), JAMAIS la config serveur du repo
        # (nginx-pisignage.conf, php-upload.ini, systemd/*.service = obsolètes/morts).
        for runtime_item in player-config.json download_queue.json playlists; do
            if [ -e "$TEMP_DIR/config/$runtime_item" ]; then
                sudo cp -r "$TEMP_DIR/config/$runtime_item" "$INSTALL_DIR/config/" 2>/dev/null || true
            fi
        done

        sudo cp "$TEMP_DIR/CLAUDE.md" "$INSTALL_DIR/" 2>/dev/null || true
        sudo cp "$TEMP_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true
        sudo cp "$TEMP_DIR/CHANGELOG.md" "$INSTALL_DIR/" 2>/dev/null || true

        # Créer le lien symbolique youtube-simple.php (compatibilité API)
        sudo ln -sf youtube.php "$INSTALL_DIR/web/api/youtube-simple.php"

        # Servir les médias en HTTP (le player charge /media/... ; --disable-web-security
        # ayant été retiré pour la sécurité, les file:// ne marchent plus depuis la page http).
        sudo ln -sfn "$INSTALL_DIR/media" "$INSTALL_DIR/web/media"

        # Corriger les permissions après copie
        sudo chown -R www-data:www-data "$INSTALL_DIR/web"

        # Nettoyer
        rm -rf "$TEMP_DIR"
        log_info "Application PiSignage déployée depuis GitHub"
    fi
}

# Téléchargement de Big Buck Bunny
download_bbb() {
    log_step "Téléchargement de Big Buck Bunny"

    local target="$INSTALL_DIR/media/BigBuckBunny_720p.mp4"
    if [ -s "$target" ]; then
        log_info "Big Buck Bunny déjà présent"
        return 0
    fi
    log_info "Téléchargement en cours (vidéo de démo optionnelle, non bloquant)..."
    # NON BLOQUANT: une URL de démo morte ne doit JAMAIS interrompre l'installation
    # (le player utilise la playlist, pas cette vidéo). Timeouts pour éviter tout blocage.
    sudo wget -q --timeout=20 --tries=2 -O "$target" "$BBB_URL" \
        || sudo wget -q --timeout=20 --tries=2 -O "$target" \
            "http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4" \
        || log_warn "Vidéo de démo non téléchargée (URL injoignable) — sans impact sur PiSignage."
    # Nettoyer un fichier vide laissé par un wget en échec
    [ -s "$target" ] || sudo rm -f "$target"
    return 0
}

# Créer le fichier de configuration config.php
create_config_php() {
    log_step "Vérification de web/config.php (déployé depuis le dépôt)"

    # SOURCE OF TRUTH: web/config.php est du CODE APPLICATIF déployé tel quel depuis le
    # dépôt (cp -r web/ plus haut). On NE le régénère PLUS depuis un heredoc périmé :
    # l'ancien heredoc était un sous-ensemble obsolète SANS sanitizeFilename/isValidMediaFile
    # ni le retrait CORS -> cause racine de BUG-014. On vérifie seulement sa présence.
    if [ -f "$INSTALL_DIR/web/config.php" ]; then
        log_info "config.php présent (source: dépôt, non régénéré)"
    else
        log_error "web/config.php manquant après la copie du dépôt — abandon"
        exit 1
    fi
    return 0

    # Bloc générateur obsolète conservé inerte (jamais atteint, cf. return 0 ci-dessus).
    sudo tee /dev/null > /dev/null << 'ENDOFCONFIG'
<?php
/**
 * PiSignage - Configuration centrale
 */

// Version
define('PISIGNAGE_VERSION', 'v0.11.0');

// Chemins
define('BASE_DIR', '/opt/pisignage');
define('MEDIA_DIR', BASE_DIR . '/media');
define('MEDIA_PATH', BASE_DIR . '/media'); // Alias pour compatibilité
define('CONFIG_PATH', BASE_DIR . '/config'); // Pour download_queue.json (YouTube)
define('PLAYLISTS_PATH', BASE_DIR . '/playlists');
define('SCREENSHOTS_DIR', BASE_DIR . '/web/screenshots');
define('SCREENSHOTS_PATH', BASE_DIR . '/web/screenshots'); // Alias
define('LOGS_DIR', BASE_DIR . '/logs');
define('LOGS_PATH', BASE_DIR . '/logs'); // Alias
define('DB_PATH', BASE_DIR . '/data/pisignage.db');

// Limites d'upload (500MB)
ini_set('upload_max_filesize', '500M');
ini_set('post_max_size', '500M');
ini_set('max_execution_time', '300');
ini_set('max_input_time', '300');

// Helper functions
function jsonResponse($success, $data = null, $message = '', $httpCode = 200) {
    http_response_code($httpCode);
    header('Content-Type: application/json');

    $response = [
        'success' => $success,
        'data' => $data,
        'message' => $message,
        'timestamp' => date('Y-m-d H:i:s')
    ];

    echo json_encode($response, JSON_PRETTY_PRINT);
    exit;
}

function logMessage($message, $level = 'INFO') {
    $logFile = LOGS_PATH . '/pisignage.log';
    $timestamp = date('Y-m-d H:i:s');
    $logLine = "[$timestamp] [$level] $message\n";
    file_put_contents($logFile, $logLine, FILE_APPEND);
}

function executeCommand($command) {
    $output = [];
    $returnCode = 0;
    exec($command, $output, $returnCode);
    return [
        'success' => $returnCode === 0,
        'output' => $output,
        'return_code' => $returnCode
    ];
}

function getMediaFiles() {
    $mediaDir = MEDIA_DIR;
    $files = [];

    if (is_dir($mediaDir)) {
        $items = scandir($mediaDir);
        foreach ($items as $item) {
            if ($item !== '.' && $item !== '..' && !is_dir($mediaDir . '/' . $item)) {
                if (!in_array(pathinfo($item, PATHINFO_EXTENSION), ['m3u', 'db', 'json'])) {
                    $files[] = [
                        'name' => $item,
                        'size' => filesize($mediaDir . '/' . $item),
                        'type' => mime_content_type($mediaDir . '/' . $item)
                    ];
                }
            }
        }
    }

    return $files;
}
?>
ENDOFCONFIG

    log_info "Fichier config.php créé"
}

# Création/mise à jour de player-config.json
create_config() {
    log_step "Vérification de player-config.json (déployé depuis le dépôt)"

    # SOURCE OF TRUTH: config/player-config.json est de la DATA déployée tel quel depuis le
    # dépôt (clone/copie plus haut). On NE le régénère PLUS depuis un heredoc périmé qui
    # réintroduisait mpv, pi_model, display=:0 (X11) et http_password=signage123 -> annulait
    # la purge mpv/Pi3 et l'alignement du mot de passe VLC. On vérifie seulement sa présence.
    if [ -f "$INSTALL_DIR/config/player-config.json" ]; then
        log_info "player-config.json présent (source: dépôt, non régénéré)"
    else
        log_error "config/player-config.json manquant après la copie du dépôt"
    fi
    return 0

    # Bloc générateur obsolète conservé inerte (jamais atteint, cf. return 0 ci-dessus).
    sudo tee /dev/null > /dev/null << 'ENDOFFILE'
{
  "player": {
    "default": "vlc",
    "current": "vlc",
    "available": ["vlc"]
  },
  "vlc": {
    "enabled": true,
    "version": "3.0.18",
    "binary": "/usr/bin/cvlc",
    "config_path": "/home/pi/.config/vlc/vlcrc",
    "http_port": 8080,
    "http_password": "signage123",
    "log_file": "/opt/pisignage/logs/vlc.log"
  },
  "mpv": {
    "enabled": false,
    "note": "MPV support removed in v0.8.9 - VLC exclusive",
    "version": "0.35.0",
    "binary": "/usr/bin/mpv",
    "config_path": "/home/pi/.config/mpv/mpv.conf",
    "socket": "/tmp/mpv-socket",
    "log_file": "/opt/pisignage/logs/mpv.log"
  },
  "system": {
    "pi_model": "auto",
    "display": ":0",
    "autostart": true,
    "watchdog": true
  }
}
ENDOFFILE

    log_info "Configuration créée"
}

# Configuration Kiosk pour Trixie
configure_kiosk_trixie() {
    if [ "${IS_TRIXIE:-0}" = "0" ]; then
        log_info "Skipping kiosk configuration (not Trixie)"
        return 0
    fi

    log_step "Configuration du mode Kiosk Chromium (Trixie)"

    # Create kiosk config directory
    sudo mkdir -p "$INSTALL_DIR/config"

    # Create default kiosk URL config
    if [ ! -f "$INSTALL_DIR/config/kiosk_url" ]; then
        echo "https://time.is" | sudo tee "$INSTALL_DIR/config/kiosk_url" >/dev/null
        log_info "Created default kiosk_url: https://time.is"
    fi

    # Create default kiosk flags
    if [ ! -f "$INSTALL_DIR/config/kiosk_flags" ]; then
        # Flags par défaut: Wayland/Ozone, décode V4L2 (pas VAAPI), pas de prompt keyring
        # (--password-store=basic), pas de barre de traduction, pas de geste tactile.
        echo "--ozone-platform=wayland --enable-features=UseOzonePlatform --disable-features=Translate,TranslateUI --password-store=basic --autoplay-policy=no-user-gesture-required --noerrdialogs --disable-infobars --no-first-run --disable-pinch --overscroll-history-navigation=0" | \
            sudo tee "$INSTALL_DIR/config/kiosk_flags" >/dev/null
        log_info "Created default kiosk_flags"
    fi

    # Policy Chromium managée : désactive définitivement la barre de traduction
    # (les flags --disable-features=Translate ne suffisent pas sur certains builds RPi)
    # ainsi que les invites navigateur par défaut. Déployée dans les 2 chemins possibles.
    for poldir in /etc/chromium/policies/managed /etc/chromium-browser/policies/managed; do
        sudo mkdir -p "$poldir"
        sudo tee "$poldir/pisignage.json" >/dev/null <<'JSON'
{
  "TranslateEnabled": false,
  "DefaultBrowserSettingEnabled": false,
  "MetricsReportingEnabled": false,
  "BackgroundModeEnabled": false,
  "SpellcheckEnabled": false
}
JSON
    done
    log_info "Policy Chromium installée (traduction désactivée)"

    # Create feature flags (kiosk + Chromium player enabled by default)
    if [ ! -f "$INSTALL_DIR/config/feature_flags" ]; then
        printf '%s\n%s\n' "ENABLE_KIOSK=1" "USE_CHROMIUM_PLAYER=1" | \
            sudo tee "$INSTALL_DIR/config/feature_flags" >/dev/null
        log_info "Created feature_flags (ENABLE_KIOSK=1, USE_CHROMIUM_PLAYER=1)"
    fi

    # Config kanshi (gestion des sorties) : kiosk mono-écran, tolérant aux 2 ports
    # micro-HDMI du Pi4. "both" en premier -> si 2 sorties remontent (ex: écran reel +
    # phantom), on n'en garde qu'une; sinon on prend la sortie unique connectee (port 0 OU 1).
    mkdir -p "$HOME/.config/kanshi"
    cat > "$HOME/.config/kanshi/config" <<'KANSHI'
profile both {
    output HDMI-A-1 enable position 0,0
    output HDMI-A-2 disable
}
profile port0 {
    output HDMI-A-1 enable position 0,0
}
profile port1 {
    output HDMI-A-2 enable position 0,0
}
KANSHI
    log_info "Config kanshi installée (kiosk mono-écran, tolérant aux 2 ports HDMI)"

    # Copy labwc rc.xml template to user's home if exists
    if [ -f "templates/.config/labwc/rc.xml" ]; then
        mkdir -p "$HOME/.config/labwc"
        cp "templates/.config/labwc/rc.xml" "$HOME/.config/labwc/rc.xml"
        log_info "Installed labwc rc.xml configuration"
    fi

    # Run kiosk-apply script to generate autostart
    if [ -x "$INSTALL_DIR/scripts/kiosk-apply" ]; then
        log_info "Running kiosk-apply to generate autostart..."
        bash "$INSTALL_DIR/scripts/kiosk-apply" || log_warn "kiosk-apply returned error (may be normal)"
    elif [ -x "scripts/kiosk-apply" ]; then
        log_info "Running kiosk-apply from current directory..."
        bash scripts/kiosk-apply || log_warn "kiosk-apply returned error (may be normal)"
    else
        log_warn "kiosk-apply script not found or not executable"
    fi

    # Autologin lightdm (R1) : sur ce Pi4/Trixie le gestionnaire de session est lightdm
    # (et non greetd). On garantit l'autologin de 'pi' vers la session par défaut (labwc)
    # pour un boot kiosk fiable OTB, sans dépendre des défauts de l'image.
    if command -v lightdm >/dev/null 2>&1; then
        sudo mkdir -p /etc/lightdm/lightdm.conf.d
        sudo tee /etc/lightdm/lightdm.conf.d/10-pisignage-autologin.conf >/dev/null <<'LIGHTDM'
[Seat:*]
autologin-user=pi
autologin-user-timeout=0
LIGHTDM
        log_info "Autologin lightdm configuré (utilisateur pi)"
    fi

    # Cron d'extinction d'écran programmée (D1) : applique screen_schedule.json chaque minute
    # via screen-schedule-tick.sh -> screen-power.sh (wlr-randr dans la session de 'pi').
    if [ -f "$INSTALL_DIR/scripts/screen-schedule-tick.sh" ]; then
        sudo chmod +x "$INSTALL_DIR/scripts/screen-schedule-tick.sh"
        echo '* * * * * root /opt/pisignage/scripts/screen-schedule-tick.sh >/dev/null 2>&1' | \
            sudo tee /etc/cron.d/pisignage-screen >/dev/null
        sudo chmod 0644 /etc/cron.d/pisignage-screen
        log_info "Cron d'extinction d'écran programmée installé"
    fi

    # Cron de PROGRAMMATION (dayparting réel, Phase 3) : exécuteur 1×/min qui lit
    # data/schedules.json et pose la playlist active selon l'heure/jour (api/scheduler.php).
    # Exécuté en www-data (même utilisateur que l'API web -> aucune divergence de permissions
    # sur media/playlist.json, config/*.json, logs/system.log).
    if [ -f "$INSTALL_DIR/web/api/scheduler.php" ]; then
        echo '* * * * * www-data /usr/bin/php /opt/pisignage/web/api/scheduler.php >/dev/null 2>&1' | \
            sudo tee /etc/cron.d/pisignage-scheduler >/dev/null
        sudo chmod 0644 /etc/cron.d/pisignage-scheduler
        log_info "Cron de programmation (dayparting) installé"
    fi

    log_info "Kiosk configuration completed"
}

# Création du script de démarrage VLC
create_vlc_script() {
    log_step "Création des scripts de contrôle"

    sudo tee $INSTALL_DIR/scripts/start-vlc.sh > /dev/null << 'ENDOFFILE'
#!/bin/bash

echo "=== PiSignage v0.11.0 - Démarrage VLC ==="

# Arrêt gracieux des lecteurs existants
systemctl --user stop pisignage-vlc.service 2>/dev/null || true
pkill -TERM vlc 2>/dev/null || true
sleep 2

# Configuration de l'environnement
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# Détection Wayland/X11
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Environnement: Wayland"
    VLC_OPTIONS="--intf dummy --vout gles2 --fullscreen --loop --no-video-title-show --quiet"
else
    echo "Environnement: X11"
    VLC_OPTIONS="--intf dummy --vout x11 --fullscreen --loop --no-video-title-show --quiet"
fi

# Fichier vidéo
VIDEO="/opt/pisignage/media/BigBuckBunny_720p.mp4"

# Si pas de BBB, chercher une autre vidéo
if [ ! -f "$VIDEO" ]; then
    VIDEO=$(find /opt/pisignage/media -name "*.mp4" -o -name "*.mkv" | head -1)
fi

# Démarrer VLC avec la commande stabilisée (compatible avec le service unifié)
if [ -n "$VIDEO" ]; then
    # Utilisation de la configuration unifiée avec HTTP interface
    vlc --intf http \
        --extraintf dummy \
        --http-host 0.0.0.0 \
        --http-port 8080 \
        --http-password pisignage \
        --fullscreen \
        --loop \
        --no-video-title-show \
        --video-on-top \
        --no-osd \
        --quiet \
        "$VIDEO" > /opt/pisignage/logs/vlc.log 2>&1 &

    VLC_PID=$!
    echo $VLC_PID > /opt/pisignage/vlc.pid
    echo "✓ VLC démarré avec $(basename "$VIDEO") et HTTP interface (PID: $VLC_PID)"
    echo "  Interface HTTP: http://localhost:8080 (mot de passe: pisignage)"
else
    echo "✗ Aucune vidéo trouvée"
    exit 1
fi
ENDOFFILE

    sudo chmod +x $INSTALL_DIR/scripts/start-vlc.sh

    # Script d'autostart
    sudo tee $INSTALL_DIR/scripts/autostart.sh > /dev/null << 'ENDOFFILE'
#!/bin/bash

# Attendre que le système soit prêt
sleep 10

# Démarrer le serveur web si nécessaire
if ! systemctl is-active --quiet nginx && ! systemctl is-active --quiet apache2; then
    cd /opt/pisignage/web
    php -S 0.0.0.0:80 index.php > /opt/pisignage/logs/php-server.log 2>&1 &
fi

# Déterminer le lecteur actif (Chromium par défaut).
# isChromiumPlayerEnabled() côté PHP: actif sauf si "USE_CHROMIUM_PLAYER=0" présent.
FEATURE_FLAGS="/opt/pisignage/config/feature_flags"
USE_CHROMIUM=1
if [ -f "$FEATURE_FLAGS" ] && grep -q "USE_CHROMIUM_PLAYER=0" "$FEATURE_FLAGS"; then
    USE_CHROMIUM=0
fi

if [ "$USE_CHROMIUM" = "1" ]; then
    # Mode Chromium kiosk: NE PAS démarrer VLC (double-propriétaire d'affichage),
    # NI watchdog VLC. Chromium est lancé par labwc/kiosk-apply.
    echo "Mode Chromium: VLC non démarré (lecteur kiosk actif)"
    exit 0
fi

# VLC retiré (v0.12) : il n'existe plus de lecteur de secours.
# USE_CHROMIUM_PLAYER=0 n'est plus supporté — on sort proprement sans rien démarrer.
echo "USE_CHROMIUM_PLAYER=0 obsolète : VLC a été retiré. Réactivez le mode Chromium."
exit 0
ENDOFFILE

    sudo chmod +x $INSTALL_DIR/scripts/autostart.sh

    log_info "Scripts créés"
}

# Configuration du serveur web
configure_webserver() {
    log_step "Configuration du serveur web"

    # SOURCE OF TRUTH: ce fichier GÉNÈRE nginx/php/systemd. config/ ne contient que
    # de la data runtime, PAS de la config serveur.

    # Détection robuste de la version PHP AVANT toute génération nginx (corrige le 502).
    PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
    if [ -z "$PHP_VERSION" ]; then
        # Dériver depuis /etc/php/*/fpm/ (plus robuste que le littéral 8.2)
        for d in /etc/php/*/fpm; do
            [ -d "$d" ] || continue
            PHP_VERSION=$(basename "$(dirname "$d")")
        done
    fi
    if [ -z "$PHP_VERSION" ]; then
        # Dernier recours: dériver depuis le socket fpm présent
        for s in /run/php/php*-fpm.sock; do
            [ -S "$s" ] || continue
            PHP_VERSION=$(echo "$s" | sed -n 's#.*/php\([0-9.]*\)-fpm.sock#\1#p')
        done
    fi
    if [ -z "$PHP_VERSION" ]; then
        log_warn "Version PHP indétectable, dérivation impossible — socket FPM peut être incorrect"
    else
        log_info "Version PHP retenue pour nginx/FPM : $PHP_VERSION"
    fi
    PHP_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"

    # Configurer nginx
    if command -v nginx > /dev/null 2>&1; then
        # Supprimer d'abord la config par défaut
        sudo rm -f /etc/nginx/sites-enabled/default

        # Sauvegarde du vhost existant avant écrasement
        sudo cp -a /etc/nginx/sites-available/pisignage /etc/nginx/sites-available/pisignage.bak.$(date +%s) 2>/dev/null || true

        sudo tee /etc/nginx/sites-available/pisignage > /dev/null << ENDOFFILE
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /opt/pisignage/web;
    index index.php index.html;

    server_name _;

    # Compression (gains transfert)
    gzip on;
    gzip_comp_level 5;
    gzip_types text/css application/javascript application/json image/svg+xml;

    # En-têtes de sécurité GLOBAUX uniquement (NE PAS ajouter X-Frame-Options/CSP
    # frame-ancestors ici: casserait /player public).
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy same-origin always;

    # Configuration des limites d'upload pour 500MB
    client_max_body_size 500M;
    client_body_buffer_size 128k;
    client_body_timeout 300s;

    # Timeouts augmentés pour les gros fichiers
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    send_timeout 300s;

    # Configuration FastCGI pour PHP
    fastcgi_connect_timeout 300s;
    fastcgi_send_timeout 300s;
    fastcgi_read_timeout 300s;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 256 16k;
    fastcgi_busy_buffers_size 256k;

    # Répertoire temporaire pour les uploads
    client_body_temp_path /tmp/nginx_upload 1 2;

    # Routage kiosk public (AVANT location /).
    # /player -> player.php (page kiosk publique).
    location = /player {
        rewrite ^ /player.php last;
    }

    # /api/playlist -> playlist.php (le bloc ~ ^/api/(.+\.php) gère ensuite playlist.php
    # et préserve SCRIPT_NAME=playlist.php pour l'exception GET du garde).
    location = /api/playlist {
        rewrite ^ /api/playlist.php last;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # Cache long pour les assets statiques
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|mp4|webm|mkv|mov)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API routes - support PATH_INFO for REST APIs
    location ~ ^/api/(.+\.php)(/.*)?$ {
        fastcgi_split_path_info ^(/api/.+\.php)(/.*)?$;
        set \$script \$fastcgi_script_name;
        set \$path_info \$fastcgi_path_info;

        fastcgi_param SCRIPT_FILENAME \$document_root\$script;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param SCRIPT_NAME \$script;

        include fastcgi_params;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;

        # Timeouts spécifiques pour PHP
        fastcgi_read_timeout 300s;
        fastcgi_send_timeout 300s;

        # Buffers pour gérer les gros uploads
        fastcgi_buffer_size 256k;
        fastcgi_buffers 256 256k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_max_temp_file_size 0;
    }

    # Défense en profondeur (2e couche): endpoints d'admin réservés au LAN.
    # JAMAIS allow 127.0.0.1 (Chromium tourne en loopback avec --disable-web-security).
    location = /api/system.php {
        allow 192.168.0.0/16;
        allow 10.0.0.0/8;
        deny all;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }
    location = /api/config.php {
        allow 192.168.0.0/16;
        allow 10.0.0.0/8;
        deny all;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }
    # NOTE: kiosk.php utilise le routage PATH_INFO (/api/kiosk.php/url, /restart...).
    # Un bloc "location = /api/kiosk.php" ne couvrirait PAS ces sous-chemins et les
    # laisserait retomber sur le bloc regex non restreint. La protection d'auth est
    # assurée par _guard.php; on ne pose donc pas de bloc IP exact ici pour ne pas
    # casser le routage REST de kiosk.php.

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;

        # Timeouts spécifiques pour PHP
        fastcgi_read_timeout 300s;
        fastcgi_send_timeout 300s;

        # Buffers pour gérer les gros uploads
        fastcgi_buffer_size 256k;
        fastcgi_buffers 256 256k;
        fastcgi_busy_buffers_size 512k;
        fastcgi_max_temp_file_size 0;
    }

    location ~ /\.ht {
        deny all;
    }

    # Logs
    access_log /opt/pisignage/logs/nginx_access.log;
    error_log /opt/pisignage/logs/nginx_error.log warn;
}
ENDOFFILE

        sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/

        # Configurer les limites PHP pour uploads (PHP_VERSION déjà détectée en tête de fonction)
        PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

        if [ -f "$PHP_INI" ]; then
            sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' "$PHP_INI"
            sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' "$PHP_INI"
            sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
            sudo sed -i 's/max_input_time = .*/max_input_time = 300/' "$PHP_INI"
            sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
            log_info "Limites PHP $PHP_VERSION configurées (500MB uploads)"
        else
            log_warn "php.ini non trouvé pour PHP $PHP_VERSION"
        fi

        # OPcache + réglages FPM (drop-in dédié PiSignage).
        # validate_timestamps=1 OBLIGATOIRE pour que les hotfix sed prennent effet.
        if [ -d "/etc/php/${PHP_VERSION}/fpm/conf.d" ]; then
            sudo tee "/etc/php/${PHP_VERSION}/fpm/conf.d/99-pisignage.ini" > /dev/null << 'ENDOFOPCACHE'
opcache.enable=1
opcache.memory_consumption=64
opcache.validate_timestamps=1
opcache.revalidate_freq=60
ENDOFOPCACHE
            log_info "OPcache configuré (drop-in 99-pisignage.ini)"
        else
            log_warn "conf.d FPM introuvable pour PHP $PHP_VERSION, OPcache non configuré"
        fi

        # Pool FPM dimensionné pour Pi 2-4Go.
        FPM_WWW_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
        if [ -f "$FPM_WWW_CONF" ]; then
            sudo sed -i 's/^pm = .*/pm = dynamic/' "$FPM_WWW_CONF"
            sudo sed -i 's/^pm.max_children = .*/pm.max_children = 8/' "$FPM_WWW_CONF"
            sudo sed -i 's/^pm.start_servers = .*/pm.start_servers = 2/' "$FPM_WWW_CONF"
            sudo sed -i 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 1/' "$FPM_WWW_CONF"
            sudo sed -i 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 3/' "$FPM_WWW_CONF"
            log_info "Pool FPM dimensionné (max_children=8)"
        else
            log_warn "Pool FPM www.conf introuvable pour PHP $PHP_VERSION"
        fi

        # Créer le répertoire temporaire pour nginx
        sudo mkdir -p /tmp/nginx_upload
        sudo chown www-data:www-data /tmp/nginx_upload

        # Recharger nginx uniquement si la config est valide (toujours nginx -t avant).
        if sudo nginx -t; then
            sudo systemctl reload nginx || sudo systemctl restart nginx
        else
            log_warn "nginx -t a échoué, vhost non rechargé"
        fi
        sudo systemctl restart php${PHP_VERSION}-fpm || true
        log_info "Nginx configuré avec PHP $PHP_VERSION"

    # Sinon essayer Apache
    elif command -v apache2 > /dev/null 2>&1; then
        sudo tee /etc/apache2/sites-available/pisignage.conf > /dev/null << ENDOFFILE
<VirtualHost *:80>
    DocumentRoot /opt/pisignage/web

    <Directory /opt/pisignage/web>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/pisignage-error.log
    CustomLog \${APACHE_LOG_DIR}/pisignage-access.log combined
</VirtualHost>
ENDOFFILE

        sudo a2enmod php* rewrite || true
        sudo a2ensite pisignage || true
        sudo a2dissite 000-default || true
        sudo systemctl restart apache2 || true
        log_info "Apache configuré"

    else
        log_warn "Aucun serveur web trouvé, utilisation du serveur PHP intégré"
    fi
}

# Configuration du démarrage automatique
configure_autostart() {
    log_step "Configuration du démarrage automatique"

    # Créer le service systemd
    sudo tee /etc/systemd/system/pisignage.service > /dev/null << ENDOFFILE
[Unit]
Description=PiSignage Digital Signage System
After=network.target graphical.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/pisignage
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u)"
ExecStart=/opt/pisignage/scripts/autostart.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
ENDOFFILE

    # Activer le service
    sudo systemctl daemon-reload
    sudo systemctl enable pisignage.service
    sudo systemctl start pisignage.service || true

    log_info "Service de démarrage automatique configuré"

    # VLC retiré (v0.12) : Chromium HTML5 (player.php sur /player) est le moteur de
    # lecture UNIQUE. Plus aucun service pisignage-vlc n'est créé / activé / démarré
    # (libère ~135 Mo RAM, supprime le « lecteur fantôme »). Le kiosk est lancé par
    # labwc/kiosk-apply ; pisignage.service ne fait qu'exécuter autostart.sh
    # (no-op en mode Chromium). Voir docs unification de la diffusion.
    log_info "Lecteur unique: Chromium kiosk (VLC retiré)"
}

# Configuration des permissions sudo (pour redémarrage)
configure_sudo() {
    log_step "Configuration des permissions"

    # Configure sudo permissions for pi user and www-data
    sudo tee /etc/sudoers.d/pisignage > /dev/null << 'SUDOERS'
# PiSignage sudo permissions
pi ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot, /bin/systemctl
www-data ALL=(ALL) NOPASSWD: /usr/bin/amixer, /usr/bin/raspi-config
# Capture d'écran Wayland: www-data (php-fpm) lance grim dans la session labwc de 'pi'
www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/grim-capture.sh
# Extinction d'écran programmée (kiosk): on/off via wlr-randr dans la session de 'pi'
www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/screen-power.sh
www-data ALL=(pi) NOPASSWD: /usr/bin/wlr-randr
# Redémarrer la session kiosk complète (alias générique lightdm/greetd)
www-data ALL=(root) NOPASSWD: /usr/bin/systemctl restart display-manager
SUDOERS

    # Ajouter www-data au groupe video (accès framebuffer pour screenshots)
    sudo usermod -aG video www-data

    # Helper de capture d'écran Wayland (grim) exécuté dans la session labwc de 'pi'.
    # php-fpm (www-data) l'invoque via `sudo -u pi` (cf. règle sudoers ci-dessus).
    sudo mkdir -p "$INSTALL_DIR/scripts"
    sudo tee "$INSTALL_DIR/scripts/grim-capture.sh" > /dev/null << 'GRIMCAP'
#!/bin/sh
# PiSignage — Capture l'écran Wayland (labwc) du kiosk. Appelé par www-data via:
#   sudo -u pi /opt/pisignage/scripts/grim-capture.sh
# Écrit un PNG dans /tmp et imprime son chemin sur stdout.
set -eu
RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
WL="$(ls "$RUNTIME_DIR" 2>/dev/null | grep -m1 '^wayland-[0-9]*$' || true)"
export WAYLAND_DISPLAY="${WL:-wayland-0}"
OUT="/tmp/pisignage-screenshot.png"
/usr/bin/grim -t png "$OUT" 2>/dev/null
chmod 0644 "$OUT" 2>/dev/null || true
echo "$OUT"
GRIMCAP
    sudo chmod 0755 "$INSTALL_DIR/scripts/grim-capture.sh"

    log_info "Permissions configurées (www-data: video group + amixer sudo + grim-capture)"
}

# Test de l'installation
test_installation() {
    log_step "Test de l'installation"

    # Vérifier que le serveur web répond
    sleep 3
    local ip=$(hostname -I | awk '{print $1}')

    if curl -s "http://localhost" > /dev/null 2>&1; then
        log_info "Serveur web OK"
    else
        log_warn "Serveur web ne répond pas encore"
    fi

    # Vérifier le service
    if systemctl is-active --quiet pisignage; then
        log_info "Service PiSignage actif"
    else
        log_warn "Service PiSignage inactif"
    fi

    # Vérifier que le lecteur kiosk (player.php) répond
    if curl -s --connect-timeout 5 http://localhost/player >/dev/null 2>&1; then
        log_info "✓ Lecteur kiosk (/player) accessible"
    else
        log_warn "Lecteur kiosk (/player) non accessible (vérifier nginx/php-fpm)"
    fi

    log_info "Tests terminés"
}

# Fonction principale
main() {
    # Parse flags (acceptés dans n'importe quel ordre): --auto, --force
    local banner_arg=""
    for arg in "$@"; do
        case "$arg" in
            --auto)  export AUTO_MODE=1; banner_arg="--auto" ;;
            --force) export FORCE_INSTALL=1 ;;
        esac
    done

    check_root
    check_hardware
    show_banner "$banner_arg"
    detect_os_version
    update_system
    install_dependencies
    create_structure
    install_managed_ytdlp
    clone_from_github
    download_bbb
    create_config_php
    create_config
    configure_kiosk_trixie
    create_vlc_script
    configure_webserver
    configure_sudo
    configure_autostart
    test_installation

    local ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}║               🎉 Installation Terminée avec Succès! 🎉              ║${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📋 Informations d'accès:"
    echo "   • Interface Web: http://${ip}"
    echo "   • Version: ${VERSION}"
    echo "   • Dossier: $INSTALL_DIR"
    echo ""
    echo "🚀 PiSignage démarre automatiquement au boot!"
    echo ""
    echo "💡 Commandes utiles:"
    echo "   sudo systemctl status pisignage       # Voir le statut principal"
    echo "   Lecteur kiosk: http://${ip}/player    # Page affichée par Chromium"
    echo "   bash $INSTALL_DIR/scripts/kiosk-apply # Régénérer l'autostart kiosk"
    echo "   tail -f $INSTALL_DIR/logs/player.log  # Logs lecteur (si présents)"
    echo ""
    echo "📝 Documentation: $INSTALL_DIR/CLAUDE.md"
    echo ""
}

# Exécuter l'installation
main "$@"