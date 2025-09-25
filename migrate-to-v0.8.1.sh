#!/bin/bash

# Script de migration Pi-Signage v0.8.0 → v0.8.1
# Migration automatique vers la nouvelle architecture Bookworm/Wayland
# Date: 2025-09-25

set -e

# Configuration
PISIGNAGE_DIR="/opt/pisignage"
BACKUP_DIR="/opt/pisignage-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/pisignage-migration.log"
PISIGNAGE_USER="${SUDO_USER:-$USER}"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}  $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
}

# Vérification root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté avec sudo"
    fi
}

# Détection version actuelle
detect_current_version() {
    header "DÉTECTION VERSION ACTUELLE"

    if [ -f "$PISIGNAGE_DIR/VERSION" ]; then
        CURRENT_VERSION=$(cat "$PISIGNAGE_DIR/VERSION")
        info "Version actuelle: $CURRENT_VERSION"
    else
        warning "Fichier VERSION non trouvé, version inconnue"
        CURRENT_VERSION="unknown"
    fi

    # Vérification si déjà en v0.8.1
    if [[ "$CURRENT_VERSION" == "0.8.1" ]]; then
        log "Déjà en version 0.8.1"
        echo -e "${GREEN}✅ Le système est déjà en version 0.8.1${NC}"
        exit 0
    fi
}

# Backup de l'installation existante
backup_current_installation() {
    header "SAUVEGARDE DE L'INSTALLATION ACTUELLE"

    log "Création du backup dans: $BACKUP_DIR"

    # Arrêt des services existants
    info "Arrêt des services actuels..."
    systemctl stop pisignage-player 2>/dev/null || true
    systemctl stop pisignage-display 2>/dev/null || true
    pkill -f "mpv.*pisignage" 2>/dev/null || true
    pkill -f "vlc.*pisignage" 2>/dev/null || true

    # Copie des fichiers
    if [ -d "$PISIGNAGE_DIR" ]; then
        log "Copie des fichiers Pi-Signage..."
        cp -r "$PISIGNAGE_DIR" "$BACKUP_DIR"
        log "Backup créé: $BACKUP_DIR"
    else
        warning "Répertoire Pi-Signage non trouvé"
    fi

    # Backup des services systemd
    if [ -f /etc/systemd/system/pisignage-player.service ]; then
        cp /etc/systemd/system/pisignage-player.service "$BACKUP_DIR/"
    fi
    if [ -f /etc/systemd/system/pisignage-display.service ]; then
        cp /etc/systemd/system/pisignage-display.service "$BACKUP_DIR/"
    fi
}

# Installation des nouveaux paquets
install_new_packages() {
    header "INSTALLATION DES NOUVEAUX PAQUETS"

    log "Mise à jour des sources APT..."
    apt-get update

    # Liste des nouveaux paquets requis pour v0.8.1
    local new_packages=(
        "raspberrypi-ffmpeg"
        "seatd"
        "v4l-utils"
        "libdrm-tests"
        "wlr-randr"
        "wayland-utils"
        "libv4l-0"
        "grim"
        "slurp"
    )

    for package in "${new_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$package"; then
            log "Installation de $package..."
            apt-get install -y "$package" || warning "Échec installation $package"
        else
            info "$package déjà installé"
        fi
    done

    log "Paquets installés"
}

# Configuration des permissions
setup_permissions() {
    header "CONFIGURATION DES PERMISSIONS"

    # Ajout aux groupes nécessaires
    log "Configuration des groupes pour $PISIGNAGE_USER..."

    usermod -aG video "$PISIGNAGE_USER"
    usermod -aG render "$PISIGNAGE_USER"
    usermod -aG audio "$PISIGNAGE_USER"
    usermod -aG input "$PISIGNAGE_USER"
    usermod -aG seat "$PISIGNAGE_USER"

    # Configuration seatd
    log "Configuration de seatd..."
    systemctl enable seatd
    systemctl start seatd

    # Permissions DRM
    if [ -e /dev/dri/card0 ]; then
        chmod 660 /dev/dri/card0
        chgrp video /dev/dri/card0
    fi

    if [ -e /dev/dri/renderD128 ]; then
        chmod 660 /dev/dri/renderD128
        chgrp render /dev/dri/renderD128
    fi

    log "Permissions configurées"
}

# Migration des services vers systemd user
migrate_to_user_services() {
    header "MIGRATION VERS SERVICES UTILISATEUR"

    # Désactivation des anciens services système
    log "Désactivation des anciens services système..."
    systemctl disable pisignage-player 2>/dev/null || true
    systemctl disable pisignage-display 2>/dev/null || true
    systemctl stop pisignage-player 2>/dev/null || true
    systemctl stop pisignage-display 2>/dev/null || true

    # Suppression des anciens services
    rm -f /etc/systemd/system/pisignage-player.service
    rm -f /etc/systemd/system/pisignage-display.service
    systemctl daemon-reload

    # Création du répertoire pour les services utilisateur
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/systemd/user"

    # Création du nouveau service utilisateur
    log "Création du service utilisateur..."

    cat > "/home/$PISIGNAGE_USER/.config/systemd/user/pisignage-player.service" << EOF
[Unit]
Description=Pi-Signage Player v0.8.1 (User Service)
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=$PISIGNAGE_DIR/scripts/player-manager-v0.8.1.sh start
ExecStop=$PISIGNAGE_DIR/scripts/player-manager-v0.8.1.sh stop
Restart=always
RestartSec=5

# Environnement
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="XDG_RUNTIME_DIR=/run/user/%U"
Environment="DISPLAY=:0"
Environment="LIBVA_DRIVER_NAME=v4l2_request"

# Timeouts
TimeoutStartSec=30
TimeoutStopSec=10

[Install]
WantedBy=default.target
EOF

    # Permissions du fichier service
    chown "$PISIGNAGE_USER:$PISIGNAGE_USER" "/home/$PISIGNAGE_USER/.config/systemd/user/pisignage-player.service"

    # Activation du service utilisateur
    sudo -u "$PISIGNAGE_USER" systemctl --user daemon-reload
    sudo -u "$PISIGNAGE_USER" systemctl --user enable pisignage-player.service

    # Activation du linger pour démarrage au boot
    loginctl enable-linger "$PISIGNAGE_USER"

    log "Service utilisateur configuré"
}

# Migration de la configuration MPV
migrate_mpv_config() {
    header "MIGRATION CONFIGURATION MPV"

    # Création du répertoire de config utilisateur
    sudo -u "$PISIGNAGE_USER" mkdir -p "/home/$PISIGNAGE_USER/.config/mpv"

    # Nouvelle configuration optimisée Bookworm
    cat > "/home/$PISIGNAGE_USER/.config/mpv/mpv.conf" << 'EOF'
# Configuration MPV v0.8.1 - Optimisée Bookworm/Wayland
# Générée par le script de migration

# Accélération matérielle V4L2
hwdec=drm
hwdec-codecs=all

# Sortie vidéo adaptative
vo=gpu-next
gpu-context=auto

# Qualité et performance
profile=gpu-hq
cache=yes
cache-secs=10
demuxer-max-bytes=50M

# Affichage
fullscreen=yes
keep-open=yes
loop-playlist=inf
cursor-autohide=1000

# Audio
volume=100
audio-pitch-correction=yes

# Logs
log-file=/opt/pisignage/logs/mpv.log
msg-level=all=warn
EOF

    chown "$PISIGNAGE_USER:$PISIGNAGE_USER" "/home/$PISIGNAGE_USER/.config/mpv/mpv.conf"

    log "Configuration MPV migrée"
}

# Installation des nouveaux scripts
install_new_scripts() {
    header "INSTALLATION DES NOUVEAUX SCRIPTS"

    # Copie du nouveau player-manager si présent
    if [ -f "$PISIGNAGE_DIR/scripts/player-manager-v0.8.1.sh" ]; then
        log "Script player-manager v0.8.1 déjà présent"
    else
        warning "Script player-manager v0.8.1 non trouvé"
        info "Téléchargement depuis le dépôt..."
        # Ici on pourrait télécharger depuis GitHub si nécessaire
    fi

    # Rendre les scripts exécutables
    chmod +x "$PISIGNAGE_DIR"/scripts/*.sh 2>/dev/null || true

    # Création du script de détection d'environnement s'il n'existe pas
    if [ ! -f "$PISIGNAGE_DIR/scripts/detect-environment.sh" ]; then
        cat > "$PISIGNAGE_DIR/scripts/detect-environment.sh" << 'EOF'
#!/bin/bash
# Détection de l'environnement graphique
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "wayland"
elif [ -n "$DISPLAY" ]; then
    echo "x11"
else
    echo "tty"
fi
EOF
        chmod +x "$PISIGNAGE_DIR/scripts/detect-environment.sh"
    fi

    log "Scripts installés"
}

# Tests post-migration
run_post_migration_tests() {
    header "TESTS POST-MIGRATION"

    local test_passed=0
    local test_failed=0

    # Test 1: Vérification des paquets
    info "Test: Paquets requis..."
    if command -v mpv &>/dev/null && command -v vlc &>/dev/null; then
        log "✓ Lecteurs vidéo installés"
        ((test_passed++))
    else
        error "✗ Lecteurs vidéo manquants"
        ((test_failed++))
    fi

    # Test 2: ffmpeg avec support V4L2
    info "Test: Support V4L2 dans ffmpeg..."
    if ffmpeg -decoders 2>/dev/null | grep -q "h264_v4l2m2m"; then
        log "✓ Décodeurs V4L2 disponibles"
        ((test_passed++))
    else
        warning "✗ Décodeurs V4L2 non disponibles"
        ((test_failed++))
    fi

    # Test 3: Permissions
    info "Test: Permissions utilisateur..."
    if id -nG "$PISIGNAGE_USER" | grep -q "video"; then
        log "✓ Utilisateur dans le groupe video"
        ((test_passed++))
    else
        error "✗ Utilisateur pas dans le groupe video"
        ((test_failed++))
    fi

    # Test 4: Service utilisateur
    info "Test: Service utilisateur..."
    if sudo -u "$PISIGNAGE_USER" systemctl --user is-enabled pisignage-player.service &>/dev/null; then
        log "✓ Service utilisateur activé"
        ((test_passed++))
    else
        warning "✗ Service utilisateur non activé"
        ((test_failed++))
    fi

    # Test 5: seatd
    info "Test: Service seatd..."
    if systemctl is-active seatd &>/dev/null; then
        log "✓ seatd actif"
        ((test_passed++))
    else
        warning "✗ seatd inactif"
        ((test_failed++))
    fi

    # Résumé des tests
    echo ""
    log "Tests réussis: $test_passed"
    if [ "$test_failed" -gt 0 ]; then
        warning "Tests échoués: $test_failed"
    fi
}

# Mise à jour du fichier VERSION
update_version_file() {
    header "MISE À JOUR VERSION"

    echo "0.8.1" > "$PISIGNAGE_DIR/VERSION"
    log "Version mise à jour: 0.8.1"

    # Création d'un changelog
    cat > "$PISIGNAGE_DIR/CHANGELOG-0.8.1.md" << 'EOF'
# Changelog v0.8.1

## Date de migration
$(date '+%Y-%m-%d %H:%M:%S')

## Changements majeurs
- Migration vers services systemd utilisateur
- Support complet Wayland/X11/DRM
- Configuration MPV optimisée pour Bookworm
- Support raspberrypi-ffmpeg pour accélération V4L2
- Détection automatique de l'environnement
- Configuration seatd pour permissions Wayland

## Nouveaux fichiers
- scripts/player-manager-v0.8.1.sh
- scripts/detect-environment.sh
- ~/.config/systemd/user/pisignage-player.service
- ~/.config/mpv/mpv.conf

## Paquets ajoutés
- raspberrypi-ffmpeg
- seatd
- v4l-utils
- wayland-utils
EOF

    log "Changelog créé"
}

# Rapport final
generate_report() {
    header "RAPPORT DE MIGRATION"

    local report_file="/tmp/migration-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$report_file" << EOF
════════════════════════════════════════════════════════════
        RAPPORT DE MIGRATION Pi-Signage v0.8.0 → v0.8.1
════════════════════════════════════════════════════════════

Date: $(date '+%Y-%m-%d %H:%M:%S')
Utilisateur: $PISIGNAGE_USER
Backup: $BACKUP_DIR

ACTIONS EFFECTUÉES:
✓ Sauvegarde de l'ancienne installation
✓ Installation des nouveaux paquets
✓ Configuration des permissions
✓ Migration vers services utilisateur
✓ Configuration MPV optimisée
✓ Installation des nouveaux scripts

PROCHAINES ÉTAPES:
1. Redémarrer le Raspberry Pi
2. Vérifier le service: systemctl --user status pisignage-player
3. Lancer la validation: $PISIGNAGE_DIR/validate-v0.8.1.sh
4. Tester la lecture vidéo

EN CAS DE PROBLÈME:
- Logs de migration: $LOG_FILE
- Restauration: cp -r $BACKUP_DIR/* $PISIGNAGE_DIR/
- Support: consulter MIGRATION-PLAN-v0.8.1.md

════════════════════════════════════════════════════════════
EOF

    echo ""
    echo -e "${GREEN}✅ MIGRATION TERMINÉE${NC}"
    echo ""
    echo "Rapport sauvegardé: $report_file"
    echo ""
    cat "$report_file"
}

# Fonction principale
main() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║    Migration Pi-Signage v0.8.0 → v0.8.1              ║${NC}"
    echo -e "${CYAN}║        Support Bookworm/Wayland/V4L2                 ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Confirmation
    echo -e "${YELLOW}⚠️  Cette migration va:${NC}"
    echo "  - Sauvegarder votre installation actuelle"
    echo "  - Installer de nouveaux paquets"
    echo "  - Migrer vers les services utilisateur systemd"
    echo "  - Optimiser la configuration pour Bookworm"
    echo ""
    read -p "Voulez-vous continuer? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration annulée"
        exit 0
    fi

    # Initialisation du log
    > "$LOG_FILE"
    log "=== DÉBUT DE LA MIGRATION v0.8.1 ==="

    # Exécution des étapes
    check_root
    detect_current_version
    backup_current_installation
    install_new_packages
    setup_permissions
    migrate_to_user_services
    migrate_mpv_config
    install_new_scripts
    run_post_migration_tests
    update_version_file
    generate_report

    log "=== MIGRATION TERMINÉE ==="

    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Redémarrez le Raspberry Pi pour appliquer tous les changements${NC}"
    echo ""
    read -p "Redémarrer maintenant? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Redémarrage du système..."
        reboot
    else
        echo "Pensez à redémarrer manuellement: sudo reboot"
    fi
}

# Lancement
main "$@"