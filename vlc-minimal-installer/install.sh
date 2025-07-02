#!/bin/bash

# =============================================================================
# Pi Signage VLC Minimal - Script d'installation
# Version: 1.0.0
# Description: Installation ultra-simple de VLC en mode kiosk
# =============================================================================

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VIDEOS_DIR="$HOME/Videos"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/vlc-kiosk.desktop"

# =============================================================================
# FONCTIONS
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

check_os() {
    print_header "Vérification du système"
    
    if [[ ! -f /etc/os-release ]]; then
        print_error "Impossible de détecter l'OS"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "raspbian" ]] && [[ "$ID" != "debian" ]]; then
        print_error "Ce script est conçu pour Raspberry Pi OS"
        exit 1
    fi
    
    print_success "OS compatible : $PRETTY_NAME"
    
    # Vérifier si on a un environnement graphique
    if ! command -v startx &> /dev/null && ! command -v wayland &> /dev/null; then
        print_error "Aucun environnement graphique détecté"
        print_info "Installez Raspberry Pi OS avec Desktop"
        exit 1
    fi
    
    print_success "Environnement graphique détecté"
}

install_vlc() {
    print_header "Installation de VLC"
    
    if command -v vlc &> /dev/null; then
        print_success "VLC est déjà installé"
        return
    fi
    
    print_info "Installation de VLC..."
    sudo apt-get update
    sudo apt-get install -y vlc
    
    print_success "VLC installé avec succès"
}

create_videos_directory() {
    print_header "Création du dossier vidéos"
    
    if [[ ! -d "$VIDEOS_DIR" ]]; then
        mkdir -p "$VIDEOS_DIR"
        print_success "Dossier créé : $VIDEOS_DIR"
    else
        print_success "Dossier existant : $VIDEOS_DIR"
    fi
    
    # Créer une vidéo de test si le dossier est vide
    if [[ -z "$(ls -A "$VIDEOS_DIR" 2>/dev/null)" ]]; then
        print_info "Création d'une vidéo de démonstration..."
        
        # Créer une vidéo de test avec ffmpeg si disponible
        if command -v ffmpeg &> /dev/null; then
            ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
                   -f lavfi -i sine=frequency=1000:duration=10 \
                   -pix_fmt yuv420p \
                   "$VIDEOS_DIR/demo-pi-signage.mp4" \
                   -y -loglevel error 2>/dev/null || true
            
            if [[ -f "$VIDEOS_DIR/demo-pi-signage.mp4" ]]; then
                print_success "Vidéo de démonstration créée"
            fi
        else
            print_info "Placez vos vidéos dans : $VIDEOS_DIR"
        fi
    else
        local video_count=$(find "$VIDEOS_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \) | wc -l)
        print_success "$video_count vidéo(s) trouvée(s) dans le dossier"
    fi
}

configure_autostart() {
    print_header "Configuration du démarrage automatique"
    
    # Créer le répertoire autostart
    mkdir -p "$AUTOSTART_DIR"
    
    # Créer le fichier .desktop
    cat > "$AUTOSTART_FILE" << EOF
[Desktop Entry]
Type=Application
Name=VLC Kiosk Mode
Comment=Lecture automatique des vidéos en boucle
Exec=vlc --intf dummy --fullscreen --loop --random --no-video-title-show --mouse-hide-timeout=0 $VIDEOS_DIR
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10
EOF
    
    chmod +x "$AUTOSTART_FILE"
    print_success "Démarrage automatique configuré"
    
    # Configurer aussi pour LXDE (Raspberry Pi OS Legacy)
    if [[ -d "$HOME/.config/lxsession/LXDE-pi" ]]; then
        mkdir -p "$HOME/.config/lxsession/LXDE-pi"
        if ! grep -q "vlc" "$HOME/.config/lxsession/LXDE-pi/autostart" 2>/dev/null; then
            echo "@vlc --intf dummy --fullscreen --loop --random --no-video-title-show $VIDEOS_DIR" >> "$HOME/.config/lxsession/LXDE-pi/autostart"
            print_success "Configuration LXDE ajoutée"
        fi
    fi
}

configure_vlc_preferences() {
    print_header "Configuration des préférences VLC"
    
    # Créer le répertoire de config VLC
    mkdir -p "$HOME/.config/vlc"
    
    # Créer une configuration minimale
    cat > "$HOME/.config/vlc/vlcrc" << 'EOF'
# Préférences VLC pour mode kiosk

# Interface
[intf] intf=dummy

# Vidéo
[core] video-title-show=0
[core] fullscreen=1

# Audio
[core] volume=100

# Playlist
[core] loop=1
[core] random=1
[core] playlist-autostart=1

# Performance
[core] avcodec-hw=any
EOF
    
    print_success "Préférences VLC configurées"
}

disable_screensaver() {
    print_header "Désactivation de l'économiseur d'écran"
    
    # Pour LXDE
    if [[ -f "$HOME/.config/lxsession/LXDE-pi/desktop.conf" ]]; then
        sed -i 's/^screensaver=.*/screensaver=0/' "$HOME/.config/lxsession/LXDE-pi/desktop.conf" 2>/dev/null || true
    fi
    
    # Pour le nouveau desktop
    if command -v xset &> /dev/null; then
        # Créer un script de désactivation
        cat > "$AUTOSTART_DIR/disable-screensaver.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Disable Screensaver
Exec=xset s off -dpms
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
        chmod +x "$AUTOSTART_DIR/disable-screensaver.desktop"
    fi
    
    print_success "Économiseur d'écran désactivé"
}

create_helper_scripts() {
    print_header "Création des scripts utilitaires"
    
    # Script pour ajouter des vidéos depuis USB
    cat > "$HOME/pi-signage-usb-import.sh" << 'EOF'
#!/bin/bash
# Import automatique depuis USB

VIDEOS_DIR="$HOME/Videos"

echo "Recherche de clés USB..."

for device in /media/pi/*; do
    if [[ -d "$device/videos" ]] || [[ -d "$device/Videos" ]]; then
        echo "Vidéos trouvées sur : $device"
        find "$device" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \) -exec cp -v {} "$VIDEOS_DIR/" \;
        echo "Import terminé !"
    fi
done

echo "Redémarrage de VLC..."
pkill vlc
sleep 2
vlc --intf dummy --fullscreen --loop --random --no-video-title-show "$VIDEOS_DIR" &
EOF
    
    chmod +x "$HOME/pi-signage-usb-import.sh"
    
    # Script de contrôle
    cat > "$HOME/pi-signage-control.sh" << 'EOF'
#!/bin/bash
# Contrôle de VLC

case "$1" in
    stop)
        pkill vlc
        echo "VLC arrêté"
        ;;
    start)
        vlc --intf dummy --fullscreen --loop --random --no-video-title-show "$HOME/Videos" &
        echo "VLC démarré"
        ;;
    restart)
        pkill vlc
        sleep 2
        vlc --intf dummy --fullscreen --loop --random --no-video-title-show "$HOME/Videos" &
        echo "VLC redémarré"
        ;;
    status)
        if pgrep vlc > /dev/null; then
            echo "VLC est en cours d'exécution"
        else
            echo "VLC est arrêté"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        ;;
esac
EOF
    
    chmod +x "$HOME/pi-signage-control.sh"
    
    print_success "Scripts utilitaires créés :"
    print_info "  ~/pi-signage-usb-import.sh - Import depuis USB"
    print_info "  ~/pi-signage-control.sh - Contrôle de VLC"
}

show_summary() {
    print_header "Installation terminée !"
    
    echo -e "${GREEN}✓ VLC installé et configuré${NC}"
    echo -e "${GREEN}✓ Démarrage automatique activé${NC}"
    echo -e "${GREEN}✓ Économiseur d'écran désactivé${NC}"
    echo ""
    echo -e "${YELLOW}Prochaines étapes :${NC}"
    echo "1. Placez vos vidéos dans : $VIDEOS_DIR"
    echo "2. Redémarrez le système : sudo reboot"
    echo ""
    echo -e "${BLUE}Commandes utiles :${NC}"
    echo "• Contrôler VLC : ~/pi-signage-control.sh {start|stop|restart|status}"
    echo "• Importer depuis USB : ~/pi-signage-usb-import.sh"
    echo ""
    echo -e "${GREEN}Profitez de votre affichage dynamique !${NC} 🎉"
}

# =============================================================================
# PROGRAMME PRINCIPAL
# =============================================================================

main() {
    clear
    
    # Bannière
    echo -e "${BLUE}"
    echo "    ____  _    ____  _                              "
    echo "   |  _ \\(_)  / ___|(_) __ _ _ __   __ _  __ _  ___ "
    echo "   | |_) | |  \\___ \\| |/ _\` | '_ \\ / _\` |/ _\` |/ _ \\"
    echo "   |  __/| |   ___) | | (_| | | | | (_| | (_| |  __/"
    echo "   |_|   |_|  |____/|_|\\__, |_| |_|\\__,_|\\__, |\\___|"
    echo "                       |___/             |___/      "
    echo ""
    echo "              VLC MINIMAL - Installation Simple"
    echo -e "${NC}"
    echo ""
    
    # Vérifications
    check_os
    
    # Installation
    install_vlc
    create_videos_directory
    configure_autostart
    configure_vlc_preferences
    disable_screensaver
    create_helper_scripts
    
    # Résumé
    show_summary
}

# Lancer le programme principal
main "$@"