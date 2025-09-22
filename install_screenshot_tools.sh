#!/bin/bash
##############################################################################
# PiSignage v0.8.0 - Installation des outils de capture d'écran
# Script d'installation automatique pour Raspberry Pi
##############################################################################

set -e

echo "=== INSTALLATION OUTILS SCREENSHOT PISIGNAGE v0.8.0 ==="
echo ""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Détection du système
log_info "Détection du système..."
if [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
    IS_RASPBERRY_PI=true
    PI_MODEL=$(cat /proc/device-tree/model)
    log_success "Raspberry Pi détecté: $PI_MODEL"
else
    IS_RASPBERRY_PI=false
    log_warning "Système non-Raspberry Pi détecté"
fi

# Mise à jour des paquets
log_info "Mise à jour de la liste des paquets..."
apt-get update -qq

# Installation de scrot (capture X11 universelle)
log_info "Installation de scrot..."
if command -v scrot >/dev/null 2>&1; then
    log_success "scrot déjà installé: $(scrot --version 2>&1 | head -1)"
else
    apt-get install -y scrot
    log_success "scrot installé avec succès"
fi

# Installation d'ImageMagick (pour import et convert)
log_info "Installation d'ImageMagick..."
if command -v convert >/dev/null 2>&1; then
    log_success "ImageMagick déjà installé: $(convert --version | head -1)"
else
    apt-get install -y imagemagick
    log_success "ImageMagick installé avec succès"
fi

# Installation de fbgrab (capture framebuffer)
log_info "Installation de fbgrab..."
if command -v fbgrab >/dev/null 2>&1; then
    log_success "fbgrab déjà installé"
else
    apt-get install -y fbgrab
    log_success "fbgrab installé avec succès"
fi

# Installation spécifique Raspberry Pi
if [[ $IS_RASPBERRY_PI == true ]]; then
    log_info "Installation des outils spécifiques Raspberry Pi..."

    # raspi2png (outil optimal pour Raspberry Pi)
    if command -v raspi2png >/dev/null 2>&1; then
        log_success "raspi2png déjà installé"
    else
        log_info "Compilation et installation de raspi2png..."

        # Dépendances pour la compilation
        apt-get install -y git build-essential

        # Téléchargement et compilation
        cd /tmp
        if [[ -d raspi2png ]]; then
            rm -rf raspi2png
        fi

        git clone https://github.com/AndrewFromMelbourne/raspi2png.git
        cd raspi2png
        make

        # Installation
        cp raspi2png /usr/local/bin/
        chmod +x /usr/local/bin/raspi2png

        # Création d'un lien symbolique pour compatibilité
        ln -sf /usr/local/bin/raspi2png /usr/bin/raspi2png

        log_success "raspi2png compilé et installé avec succès"
        cd /
        rm -rf /tmp/raspi2png
    fi

    # Configuration GPU pour raspi2png
    log_info "Configuration GPU pour raspi2png..."
    if grep -q "gpu_mem=" /boot/config.txt; then
        log_info "Mémoire GPU déjà configurée"
    else
        echo "gpu_mem=128" >> /boot/config.txt
        log_warning "Mémoire GPU configurée à 128MB - REDÉMARRAGE REQUIS"
    fi
fi

# Test des outils installés
echo ""
log_info "=== VÉRIFICATION DES INSTALLATIONS ==="

tools=("scrot" "convert" "import" "fbgrab")
if [[ $IS_RASPBERRY_PI == true ]]; then
    tools+=("raspi2png")
fi

working_tools=()
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        log_success "$tool: DISPONIBLE"
        working_tools+=("$tool")
    else
        log_error "$tool: NON DISPONIBLE"
    fi
done

# Configuration des permissions
log_info "Configuration des permissions..."

# Ajout de www-data au groupe video (pour framebuffer)
if groups www-data | grep -q video; then
    log_success "www-data déjà dans le groupe video"
else
    usermod -a -G video www-data
    log_success "www-data ajouté au groupe video"
fi

# Permissions sur /dev/shm
if [[ -d /dev/shm ]]; then
    chmod 755 /dev/shm
    log_success "Permissions /dev/shm configurées"
fi

# Création du cache screenshot
mkdir -p /dev/shm/pisignage
chown www-data:www-data /dev/shm/pisignage
chmod 755 /dev/shm/pisignage
log_success "Cache screenshot créé dans /dev/shm/pisignage"

# Test de capture basique
echo ""
log_info "=== TEST DE CAPTURE ==="

test_file="/tmp/test_screenshot.png"
test_success=false

# Test avec le meilleur outil disponible
if [[ $IS_RASPBERRY_PI == true ]] && command -v raspi2png >/dev/null 2>&1; then
    log_info "Test avec raspi2png..."
    if timeout 10 raspi2png -p "$test_file" 2>/dev/null; then
        if [[ -f "$test_file" ]] && [[ $(stat -f%z "$test_file" 2>/dev/null || stat -c%s "$test_file") -gt 1000 ]]; then
            log_success "Test raspi2png: SUCCÈS"
            test_success=true
            rm -f "$test_file"
        fi
    fi
fi

if [[ $test_success == false ]] && command -v scrot >/dev/null 2>&1; then
    log_info "Test avec scrot..."
    if timeout 10 scrot "$test_file" 2>/dev/null; then
        if [[ -f "$test_file" ]] && [[ $(stat -f%z "$test_file" 2>/dev/null || stat -c%s "$test_file") -gt 1000 ]]; then
            log_success "Test scrot: SUCCÈS"
            test_success=true
            rm -f "$test_file"
        fi
    fi
fi

# Résumé final
echo ""
echo "=== RÉSUMÉ DE L'INSTALLATION ==="
echo "Outils installés: ${working_tools[*]}"
echo "Cache configuré: /dev/shm/pisignage"
echo "Utilisateur web: www-data (groupe video)"

if [[ $test_success == true ]]; then
    log_success "Installation terminée avec succès !"
    log_success "L'API screenshot de PiSignage v0.8.0 est prête à l'utilisation"
else
    log_warning "Installation terminée mais aucun test de capture réussi"
    log_warning "Vérifiez la configuration du serveur X11 ou du framebuffer"
fi

if [[ $IS_RASPBERRY_PI == true ]]; then
    echo ""
    log_info "NOTES IMPORTANTES POUR RASPBERRY PI:"
    echo "• raspi2png nécessite l'allocation GPU (gpu_mem=128 dans /boot/config.txt)"
    echo "• Un redémarrage peut être nécessaire si la configuration GPU a été modifiée"
    echo "• raspi2png offre les meilleures performances (25ms pour du 1080p)"
fi

echo ""
log_info "Vous pouvez maintenant tester l'API avec:"
echo "curl 'http://localhost/api/screenshot.php?action=status'"
echo "curl 'http://localhost/api/screenshot.php?action=capture&format=png&quality=85'"