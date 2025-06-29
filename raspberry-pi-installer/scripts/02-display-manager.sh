#!/usr/bin/env bash

# =============================================================================
# Module 02 - Installation du Gestionnaire d'Affichage
# Version: 2.1.0
# Description: Installation X11 + LightDM pour Digital Signage
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTES
# =============================================================================

readonly CONFIG_FILE="/etc/pi-signage/config.conf"
readonly LOG_FILE="/var/log/pi-signage-setup.log"
readonly LIGHTDM_CONFIG="/etc/lightdm/lightdm.conf"
readonly XORG_CONFIG="/etc/X11/xorg.conf.d/99-fbdev.conf"
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
    echo -e "${GREEN}[DISPLAY]${NC} $*"
}

log_warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [WARN] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${YELLOW}[DISPLAY]${NC} $*"
}

log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [ERROR] $*" >> "${LOG_FILE}" 2>/dev/null || true
    echo -e "${RED}[DISPLAY]${NC} $*" >&2
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
# INSTALLATION DES PAQUETS X11
# =============================================================================

install_x11_packages() {
    log_info "Installation des paquets X11 et gestionnaire d'affichage..."
    
    # Paquets nécessaires pour X11 et LightDM
    local x11_packages=(
        "xserver-xorg"
        "xserver-xorg-video-fbdev"
        "xserver-xorg-input-libinput"
        "lightdm"
        "openbox"
        "xterm"
        "x11-xserver-utils"
        "xinit"
        "xorg"
        "fonts-dejavu-core"
        "unclutter"
    )
    
    # Installation avec gestion des erreurs
    log_info "Installation en cours... (cela peut prendre quelques minutes)"
    
    if apt-get install -y "${x11_packages[@]}"; then
        log_info "Paquets X11 installés avec succès"
    else
        log_error "Échec de l'installation des paquets X11"
        return 1
    fi
    
    # Vérification de l'installation
    if command -v lightdm >/dev/null 2>&1; then
        log_info "LightDM installé et disponible"
    else
        log_error "LightDM non disponible après installation"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION DE LIGHTDM
# =============================================================================

configure_lightdm() {
    log_info "Configuration de LightDM pour l'auto-login..."
    
    # Création de l'utilisateur signage s'il n'existe pas
    if ! id "signage" >/dev/null 2>&1; then
        log_info "Création de l'utilisateur signage"
        useradd -m -s /bin/bash signage
        
        # Ajout aux groupes nécessaires
        usermod -a -G video,audio,input,render,gpio signage
        
        # Pas de mot de passe nécessaire pour l'auto-login
        passwd -d signage
        
        log_info "Utilisateur signage créé"
    else
        log_info "Utilisateur signage déjà existant"
    fi
    
    # Configuration de LightDM pour auto-login
    if [[ -f "$LIGHTDM_CONFIG" ]]; then
        # Sauvegarde de la configuration originale
        cp "$LIGHTDM_CONFIG" "${LIGHTDM_CONFIG}.backup-$(date +%Y%m%d)" 2>/dev/null || true
    fi
    
    # Configuration LightDM
    cat > "$LIGHTDM_CONFIG" << 'EOF'
[Seat:*]
# Auto-login configuration for digital signage
autologin-user=signage
autologin-user-timeout=0
autologin-session=openbox
user-session=openbox

# Display configuration
display-setup-script=/opt/scripts/display-setup.sh
session-setup-script=/opt/scripts/session-setup.sh

# Security settings for kiosk mode
allow-guest=false
greeter-hide-users=true
greeter-show-manual-login=false

# Performance settings
minimum-display-number=7
EOF
    
    log_info "LightDM configuré pour auto-login utilisateur 'signage'"
}

# =============================================================================
# CONFIGURATION D'OPENBOX
# =============================================================================

configure_openbox() {
    log_info "Configuration d'Openbox pour le mode kiosque..."
    
    local signage_home="/home/signage"
    local openbox_dir="$signage_home/.config/openbox"
    
    # Création des répertoires de configuration
    mkdir -p "$openbox_dir"
    
    # Configuration Openbox pour mode kiosque
    cat > "$openbox_dir/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>
  
  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>
  
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>
  
  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>no</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow">
      <name>Sans</name>
      <size>8</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>Sans</name>
      <size>8</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
  </theme>
  
  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Digital Signage</name>
    </names>
    <popupTime>0</popupTime>
  </desktops>
  
  <resize>
    <drawContents>yes</drawContents>
    <popupShow>Nonpixel</popupShow>
    <popupPosition>Center</popupPosition>
    <popupFixedPosition>
      <x>10</x>
      <y>10</y>
    </popupFixedPosition>
  </resize>
  
  <applications>
    <application name="vlc">
      <fullscreen>yes</fullscreen>
      <maximized>yes</maximized>
      <decor>no</decor>
      <focus>yes</focus>
      <desktop>1</desktop>
      <layer>above</layer>
    </application>
  </applications>
</openbox_config>
EOF
    
    # Script d'auto-démarrage Openbox
    cat > "$openbox_dir/autostart" << 'EOF'
#!/bin/bash

# Charger les fonctions de sécurité si disponibles
if [[ -f "/opt/scripts/00-security-utils.sh" ]]; then
    source "/opt/scripts/00-security-utils.sh"
fi

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Masquer le curseur
unclutter -idle 1 &

# Attendre que le système soit complètement prêt
echo "Attente de la stabilisation du système..."

# Attendre que X11 soit complètement initialisé
if command -v wait_for_process >/dev/null 2>&1; then
    wait_for_process "Xorg" 30 2
else
    # Fallback si les fonctions de sécurité ne sont pas disponibles
    sleep 10
fi

# Vérifier que le display est disponible
for i in {1..10}; do
    if xset q >/dev/null 2>&1; then
        echo "Display X11 disponible après $i tentatives"
        break
    fi
    sleep 2
done

# Démarrer VLC en mode signage seulement quand tout est prêt
if [[ -f "/opt/scripts/vlc-signage.sh" ]]; then
    echo "Démarrage de VLC..."
    /opt/scripts/vlc-signage.sh &
else
    echo "ERREUR: Script VLC introuvable"
fi
EOF
    
    chmod +x "$openbox_dir/autostart"
    
    # Permissions pour l'utilisateur signage
    chown -R signage:signage "$signage_home/.config"
    
    log_info "Openbox configuré pour mode kiosque"
}

# =============================================================================
# SCRIPTS DE CONFIGURATION D'AFFICHAGE
# =============================================================================

create_display_scripts() {
    log_info "Création des scripts de configuration d'affichage..."
    
    # Script de configuration d'affichage
    cat > "/opt/scripts/display-setup.sh" << 'EOF'
#!/bin/bash

# Configuration d'affichage pour digital signage

# Variables d'environnement X11
export DISPLAY=:7.0

# Configuration de l'affichage
xrandr --output HDMI-1 --mode 1920x1080 --rate 60 2>/dev/null || \
xrandr --output HDMI-A-1 --mode 1920x1080 --rate 60 2>/dev/null || \
xrandr --output HDMI1 --mode 1920x1080 --rate 60 2>/dev/null || true

# Désactiver l'économiseur d'écran
xset s off
xset -dpms
xset s noblank

# Configuration du clavier (optionnel)
setxkbmap fr 2>/dev/null || setxkbmap us 2>/dev/null || true

echo "Configuration d'affichage terminée"
EOF
    
    # Script de configuration de session
    cat > "/opt/scripts/session-setup.sh" << 'EOF'
#!/bin/bash

# Configuration de session pour digital signage

# Variables d'environnement
export DISPLAY=:7.0
export HOME=/home/signage

# Log de démarrage
echo "$(date): Session signage démarrée" >> /var/log/pi-signage/session.log

# Démarrage différé pour s'assurer que tout est prêt
sleep 3

# S'assurer que l'utilisateur signage a les bonnes permissions
chown signage:signage /home/signage/.Xauthority 2>/dev/null || true

echo "Configuration de session terminée"
EOF
    
    # Rendre les scripts exécutables
    chmod +x /opt/scripts/display-setup.sh
    chmod +x /opt/scripts/session-setup.sh
    
    log_info "Scripts de configuration d'affichage créés"
}

# =============================================================================
# CONFIGURATION XORG
# =============================================================================

configure_xorg() {
    log_info "Configuration de Xorg pour l'affichage..."
    
    # Créer le répertoire de configuration
    mkdir -p /etc/X11/xorg.conf.d
    
    # Configuration Xorg pour Raspberry Pi
    cat > "$XORG_CONFIG" << 'EOF'
Section "Device"
    Identifier "Raspberry Pi FB"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "SWcursor" "true"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "Raspberry Pi FB"
    Monitor "Default Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080" "1680x1050" "1280x1024" "1024x768"
    EndSubSection
EndSection

Section "Monitor"
    Identifier "Default Monitor"
    HorizSync 30-70
    VertRefresh 50-75
    Option "PreferredMode" "1920x1080"
EndSection

Section "ServerLayout"
    Identifier "Default Layout"
    Screen "Default Screen"
EndSection
EOF
    
    log_info "Configuration Xorg créée"
}

# =============================================================================
# ACTIVATION DES SERVICES
# =============================================================================

enable_display_services() {
    log_info "Activation des services d'affichage..."
    
    # Activation de LightDM
    if systemctl enable lightdm; then
        log_info "Service LightDM activé"
    else
        log_error "Échec de l'activation de LightDM"
        return 1
    fi
    
    # Définir LightDM comme gestionnaire d'affichage par défaut
    systemctl set-default graphical.target
    
    # NE PAS démarrer LightDM maintenant pour éviter les race conditions
    # Il démarrera au prochain redémarrage
    log_info "Services d'affichage activés (démarrage au prochain boot)"
    log_info "Note: LightDM démarrera après le redémarrage pour éviter les conflits"
}

# =============================================================================
# VALIDATION DE L'INSTALLATION
# =============================================================================

validate_display_installation() {
    log_info "Validation de l'installation du gestionnaire d'affichage..."
    
    local errors=0
    
    # Vérification des paquets installés
    local required_commands=("lightdm" "openbox" "xrandr" "unclutter")
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "✓ Commande $cmd disponible"
        else
            log_error "✗ Commande $cmd manquante"
            ((errors++))
        fi
    done
    
    # Vérification de l'utilisateur signage
    if id "signage" >/dev/null 2>&1; then
        log_info "✓ Utilisateur signage créé"
    else
        log_error "✗ Utilisateur signage manquant"
        ((errors++))
    fi
    
    # Vérification des fichiers de configuration
    local config_files=("$LIGHTDM_CONFIG" "/home/signage/.config/openbox/rc.xml")
    for config in "${config_files[@]}"; do
        if [[ -f "$config" ]]; then
            log_info "✓ Configuration $config présente"
        else
            log_error "✗ Configuration $config manquante"
            ((errors++))
        fi
    done
    
    # Vérification du service LightDM
    if systemctl is-enabled lightdm >/dev/null 2>&1; then
        log_info "✓ Service LightDM activé"
    else
        log_error "✗ Service LightDM non activé"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== DÉBUT: Installation Gestionnaire d'Affichage ==="
    
    # Chargement de la configuration
    if ! load_config; then
        return 1
    fi
    
    # Étapes d'installation
    local steps=(
        "install_x11_packages"
        "configure_lightdm"
        "configure_openbox"
        "create_display_scripts"
        "configure_xorg"
        "enable_display_services"
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
    if validate_display_installation; then
        log_info "Gestionnaire d'affichage installé avec succès"
    else
        log_warn "Gestionnaire d'affichage installé avec des avertissements"
    fi
    
    # Rapport des échecs
    if [[ ${#failed_steps[@]} -gt 0 ]]; then
        log_error "Étapes ayant échoué: ${failed_steps[*]}"
        return 1
    fi
    
    log_info "=== FIN: Installation Gestionnaire d'Affichage ==="
    return 0
}

# =============================================================================
# EXÉCUTION
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

main "$@"