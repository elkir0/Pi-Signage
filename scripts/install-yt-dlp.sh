#!/bin/bash
# PiSignage v0.8.0 - yt-dlp Installation Script
# Compatible avec Raspberry Pi OS Bullseye

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/install-yt-dlp.log"

# Créer le dossier logs s'il n'existe pas
mkdir -p "$PROJECT_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Installation yt-dlp pour PiSignage v0.8.0 ==="
log "Architecture: $(uname -m)"
log "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"

# Vérifier si on est root ou avec sudo
if [[ $EUID -eq 0 ]]; then
    SUDO=""
    log "Running as root"
else
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
        log "Using sudo for elevated permissions"
    else
        log "ERROR: This script requires root privileges or sudo"
        exit 1
    fi
fi

# Fonction pour détecter la version Python disponible
detect_python() {
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        log "Found Python 3: $PYTHON_VERSION"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
        if [[ $PYTHON_VERSION == 3.* ]]; then
            PYTHON_CMD="python"
            log "Found Python 3: $PYTHON_VERSION"
        else
            log "ERROR: Python 3 is required, found Python $PYTHON_VERSION"
            exit 1
        fi
    else
        log "ERROR: Python 3 is not installed"
        exit 1
    fi
}

# Fonction pour détecter pip
detect_pip() {
    if command -v pip3 >/dev/null 2>&1; then
        PIP_CMD="pip3"
        log "Found pip3"
    elif command -v pip >/dev/null 2>&1; then
        # Vérifier si pip correspond à Python 3
        PIP_VERSION=$($PYTHON_CMD -m pip --version 2>/dev/null | head -1)
        if [[ -n "$PIP_VERSION" ]]; then
            PIP_CMD="$PYTHON_CMD -m pip"
            log "Found pip via Python module: $PIP_VERSION"
        else
            log "pip not found, will install it"
            PIP_CMD=""
        fi
    else
        log "pip not found, will install it"
        PIP_CMD=""
    fi
}

# Installer pip si nécessaire
install_pip() {
    if [[ -z "$PIP_CMD" ]]; then
        log "Installing pip..."

        # Mettre à jour les paquets
        log "Updating package list..."
        $SUDO apt-get update -qq

        # Installer pip
        if [[ "$PYTHON_CMD" == "python3" ]]; then
            $SUDO apt-get install -y python3-pip
            PIP_CMD="pip3"
        else
            $SUDO apt-get install -y python-pip
            PIP_CMD="pip"
        fi

        log "pip installed successfully"
    fi
}

# Vérifier si yt-dlp est déjà installé
check_existing_ytdlp() {
    if command -v yt-dlp >/dev/null 2>&1; then
        EXISTING_VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
        log "yt-dlp already installed: version $EXISTING_VERSION"
        read -p "Do you want to update to the latest version? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation cancelled by user"
            exit 0
        fi
        UPDATE_MODE=true
    else
        log "yt-dlp not found, will install fresh"
        UPDATE_MODE=false
    fi
}

# Installer les dépendances système requises
install_dependencies() {
    log "Installing system dependencies..."

    # Dépendances pour yt-dlp et ffmpeg
    PACKAGES=(
        "ffmpeg"
        "curl"
        "wget"
        "python3-dev"
        "python3-setuptools"
        "ca-certificates"
    )

    for package in "${PACKAGES[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            log "$package is already installed"
        else
            log "Installing $package..."
            $SUDO apt-get install -y "$package"
        fi
    done
}

# Installer yt-dlp
install_ytdlp() {
    log "Installing yt-dlp..."

    # Méthode 1: Via pip (recommandée)
    if [[ -n "$PIP_CMD" ]]; then
        log "Installing yt-dlp via pip..."
        if $UPDATE_MODE; then
            $SUDO $PIP_CMD install --upgrade yt-dlp
        else
            $SUDO $PIP_CMD install yt-dlp
        fi

        # Vérifier l'installation
        if command -v yt-dlp >/dev/null 2>&1; then
            VERSION=$(yt-dlp --version)
            log "yt-dlp installed successfully via pip: version $VERSION"
            return 0
        fi
    fi

    log "pip installation failed, trying direct download..."

    # Méthode 2: Téléchargement direct
    INSTALL_DIR="/usr/local/bin"
    YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"

    log "Downloading yt-dlp binary..."
    $SUDO curl -L "$YTDLP_URL" -o "$INSTALL_DIR/yt-dlp"
    $SUDO chmod +x "$INSTALL_DIR/yt-dlp"

    # Vérifier l'installation
    if command -v yt-dlp >/dev/null 2>&1; then
        VERSION=$(yt-dlp --version)
        log "yt-dlp installed successfully via direct download: version $VERSION"
    else
        log "ERROR: yt-dlp installation failed"
        exit 1
    fi
}

# Tester yt-dlp avec une vidéo de test
test_ytdlp() {
    log "Testing yt-dlp installation..."

    # Créer un dossier de test temporaire
    TEST_DIR="/tmp/pisignage-ytdlp-test"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # URL de test YouTube courte et fiable
    TEST_URL="https://www.youtube.com/watch?v=jNQXAC9IVRw"  # Me at the zoo (première vidéo YouTube)

    # Test avec extraction d'informations seulement
    log "Testing video info extraction..."
    if yt-dlp --dump-json --no-download "$TEST_URL" >/dev/null 2>&1; then
        log "✓ Video info extraction test passed"
    else
        log "⚠ Video info extraction test failed (this might be due to network or YouTube restrictions)"
    fi

    # Test format listing
    log "Testing format listing..."
    if yt-dlp -F "$TEST_URL" >/dev/null 2>&1; then
        log "✓ Format listing test passed"
    else
        log "⚠ Format listing test failed"
    fi

    # Nettoyage
    cd / && rm -rf "$TEST_DIR"

    log "Basic tests completed"
}

# Créer un script de mise à jour
create_update_script() {
    UPDATE_SCRIPT="$PROJECT_DIR/scripts/update-yt-dlp.sh"

    cat > "$UPDATE_SCRIPT" << 'EOF'
#!/bin/bash
# yt-dlp Update Script for PiSignage

LOG_FILE="/opt/pisignage/logs/update-yt-dlp.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Updating yt-dlp..."

# Essayer via pip d'abord
if command -v pip3 >/dev/null 2>&1; then
    if pip3 install --upgrade yt-dlp 2>>"$LOG_FILE"; then
        VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
        log "yt-dlp updated via pip3: version $VERSION"
        exit 0
    fi
fi

# Fallback: téléchargement direct
if curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp" -o "/usr/local/bin/yt-dlp.new" 2>>"$LOG_FILE"; then
    chmod +x "/usr/local/bin/yt-dlp.new"
    mv "/usr/local/bin/yt-dlp.new" "/usr/local/bin/yt-dlp"
    VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
    log "yt-dlp updated via direct download: version $VERSION"
else
    log "ERROR: Failed to update yt-dlp"
    exit 1
fi
EOF

    chmod +x "$UPDATE_SCRIPT"
    log "Created update script: $UPDATE_SCRIPT"
}

# Ajouter une entrée cron pour les mises à jour automatiques (optionnel)
setup_auto_update() {
    read -p "Do you want to enable automatic weekly updates for yt-dlp? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CRON_JOB="0 3 * * 0 $PROJECT_DIR/scripts/update-yt-dlp.sh >/dev/null 2>&1"

        # Vérifier si la tâche cron existe déjà
        if crontab -l 2>/dev/null | grep -q "update-yt-dlp.sh"; then
            log "Cron job for yt-dlp updates already exists"
        else
            # Ajouter la tâche cron
            (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
            log "Added weekly auto-update cron job for yt-dlp"
        fi
    else
        log "Auto-update not enabled"
    fi
}

# Configuration pour PiSignage
configure_for_pisignage() {
    log "Configuring yt-dlp for PiSignage..."

    # Créer un fichier de configuration yt-dlp
    CONFIG_DIR="$HOME/.config/yt-dlp"
    mkdir -p "$CONFIG_DIR"

    CONFIG_FILE="$CONFIG_DIR/config"
    cat > "$CONFIG_FILE" << EOF
# yt-dlp configuration for PiSignage v0.8.0

# Préférer MP4 pour la compatibilité
--format 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best'

# Limiter la qualité pour éviter les fichiers trop volumineux
--format-sort 'height:720'

# Dossier de sortie par défaut
--output '/opt/pisignage/media/%(title)s.%(ext)s'

# Options de qualité audio pour extraction
--audio-quality 192K

# Metadata
--add-metadata
--embed-thumbnail

# Retry et timeout
--retries 3
--fragment-retries 3
--retry-sleep 5
EOF

    log "Created yt-dlp configuration file: $CONFIG_FILE"
}

# Afficher les informations finales
show_final_info() {
    log "=== Installation Summary ==="

    if command -v yt-dlp >/dev/null 2>&1; then
        VERSION=$(yt-dlp --version)
        LOCATION=$(which yt-dlp)
        log "✓ yt-dlp version: $VERSION"
        log "✓ Location: $LOCATION"
    else
        log "✗ yt-dlp not found in PATH"
        exit 1
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        FFMPEG_VERSION=$(ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3)
        log "✓ ffmpeg version: $FFMPEG_VERSION"
    else
        log "✗ ffmpeg not found"
    fi

    log ""
    log "Installation completed successfully!"
    log "You can now use the YouTube download feature in PiSignage."
    log ""
    log "Test commands:"
    log "  yt-dlp --version"
    log "  yt-dlp -F 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    log ""
    log "Log file: $LOG_FILE"
}

# Exécution principale
main() {
    detect_python
    detect_pip
    check_existing_ytdlp
    install_dependencies
    install_pip
    install_ytdlp
    test_ytdlp
    create_update_script
    configure_for_pisignage
    setup_auto_update
    show_final_info
}

# Gestion des erreurs
trap 'log "ERROR: Installation failed at line $LINENO"' ERR

# Lancer l'installation
main "$@"

log "Installation script completed at $(date)"