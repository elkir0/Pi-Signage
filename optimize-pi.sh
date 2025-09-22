#!/bin/bash

# PiSignage v0.8.0 - Optimisation Raspberry Pi
# GPU, CPU, mémoire, boot et services
# Auteur: Claude Code
# Date: 22/09/2025

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
PISIGNAGE_USER="pi"
BOOT_CONFIG="/boot/config.txt"
CMDLINE_CONFIG="/boot/cmdline.txt"

log() {
    echo -e "${GREEN}[OPT] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[OPT] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[OPT] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[OPT] INFO: $1${NC}"
}

# Détection du modèle de Raspberry Pi
detect_pi_model() {
    log "Détection du modèle Raspberry Pi..."

    local model=""
    if [ -f /proc/cpuinfo ]; then
        model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
        info "Modèle détecté: $model"
    else
        warn "Impossible de détecter le modèle"
        model="Unknown"
    fi

    # Détection des capacités
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_gb=$((mem_total / 1024 / 1024))
    info "Mémoire totale: ${mem_gb}GB"

    # Export pour utilisation dans d'autres fonctions
    export PI_MODEL="$model"
    export PI_MEMORY_GB="$mem_gb"

    log "✅ Détection terminée"
}

# Optimisation GPU et mémoire
optimize_gpu_memory() {
    log "Optimisation GPU et mémoire..."

    # Backup du fichier config
    sudo cp "$BOOT_CONFIG" "${BOOT_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

    # Configuration GPU en fonction de la mémoire disponible
    local gpu_mem=128
    if [ "$PI_MEMORY_GB" -ge 4 ]; then
        gpu_mem=256
    elif [ "$PI_MEMORY_GB" -ge 2 ]; then
        gpu_mem=128
    else
        gpu_mem=64
    fi

    # Application de la configuration GPU
    if grep -q "^gpu_mem=" "$BOOT_CONFIG"; then
        sudo sed -i "s/^gpu_mem=.*/gpu_mem=$gpu_mem/" "$BOOT_CONFIG"
    else
        echo "gpu_mem=$gpu_mem" | sudo tee -a "$BOOT_CONFIG"
    fi

    log "✅ GPU memory configurée: ${gpu_mem}MB"

    # Configuration avancée GPU
    local gpu_configs=(
        "dtoverlay=vc4-fkms-v3d"
        "max_framebuffers=2"
        "hdmi_force_hotplug=1"
        "hdmi_drive=2"
        "disable_splash=1"
    )

    for config in "${gpu_configs[@]}"; do
        if ! grep -q "^$config" "$BOOT_CONFIG"; then
            echo "$config" | sudo tee -a "$BOOT_CONFIG"
            log "✅ Ajouté: $config"
        fi
    done

    log "✅ Configuration GPU terminée"
}

# Overclocking stable
configure_overclocking() {
    log "Configuration overclocking stable..."

    # Overclocking sécurisé basé sur le modèle
    case "$PI_MODEL" in
        *"Pi 4"*)
            log "Configuration Pi 4..."
            local oc_configs=(
                "over_voltage=2"
                "arm_freq=1750"
                "gpu_freq=600"
            )
            ;;
        *"Pi 3"*)
            log "Configuration Pi 3..."
            local oc_configs=(
                "over_voltage=2"
                "arm_freq=1300"
                "gpu_freq=400"
            )
            ;;
        *)
            warn "Modèle non reconnu, overclocking conservateur"
            local oc_configs=(
                "over_voltage=1"
                "arm_freq=1200"
            )
            ;;
    esac

    for config in "${oc_configs[@]}"; do
        if ! grep -q "^$config" "$BOOT_CONFIG"; then
            echo "$config" | sudo tee -a "$BOOT_CONFIG"
            log "✅ Ajouté: $config"
        fi
    done

    # Configuration de refroidissement
    if ! grep -q "^temp_limit=" "$BOOT_CONFIG"; then
        echo "temp_limit=80" | sudo tee -a "$BOOT_CONFIG"
        log "✅ Limite température: 80°C"
    fi

    log "✅ Overclocking configuré"
}

# Optimisation du boot
optimize_boot() {
    log "Optimisation du boot..."

    # Backup cmdline.txt
    sudo cp "$CMDLINE_CONFIG" "${CMDLINE_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

    # Paramètres de boot optimisés
    local current_cmdline=$(cat "$CMDLINE_CONFIG")

    # Ajout des paramètres d'optimisation s'ils n'existent pas
    local boot_params=(
        "quiet"
        "splash"
        "plymouth.ignore-serial-consoles"
        "fastboot"
        "noatime"
        "nodiratime"
    )

    for param in "${boot_params[@]}"; do
        if [[ "$current_cmdline" != *"$param"* ]]; then
            current_cmdline="$current_cmdline $param"
            log "✅ Ajouté paramètre boot: $param"
        fi
    done

    echo "$current_cmdline" | sudo tee "$CMDLINE_CONFIG" > /dev/null

    # Configuration boot dans config.txt
    local boot_configs=(
        "disable_overscan=1"
        "disable_splash=1"
        "boot_delay=0"
        "initial_turbo=30"
    )

    for config in "${boot_configs[@]}"; do
        if ! grep -q "^$config" "$BOOT_CONFIG"; then
            echo "$config" | sudo tee -a "$BOOT_CONFIG"
            log "✅ Ajouté config boot: $config"
        fi
    done

    log "✅ Boot optimisé"
}

# Désactivation des services inutiles
disable_unnecessary_services() {
    log "Désactivation des services inutiles..."

    # Services à désactiver pour un affichage digital
    local services_to_disable=(
        "bluetooth"
        "hciuart"
        "ModemManager"
        "wpa_supplicant"  # Si ethernet uniquement
        "avahi-daemon"
        "triggerhappy"
        "dphys-swapfile"  # Si RAM suffisante
    )

    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null | grep -q enabled; then
            sudo systemctl disable "$service" 2>/dev/null || true
            sudo systemctl stop "$service" 2>/dev/null || true
            log "✅ Service désactivé: $service"
        else
            info "Service déjà désactivé ou inexistant: $service"
        fi
    done

    # Désactiver Bluetooth dans config.txt
    if ! grep -q "^dtoverlay=disable-bt" "$BOOT_CONFIG"; then
        echo "dtoverlay=disable-bt" | sudo tee -a "$BOOT_CONFIG"
        log "✅ Bluetooth désactivé"
    fi

    log "✅ Services inutiles désactivés"
}

# Optimisation système de fichiers
optimize_filesystem() {
    log "Optimisation du système de fichiers..."

    # Configuration fstab pour performance
    local fstab_backup="/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/fstab "$fstab_backup"

    # Ajout des options noatime et nodiratime si pas présentes
    if ! grep -q "noatime" /etc/fstab; then
        sudo sed -i 's/defaults/defaults,noatime,nodiratime/' /etc/fstab
        log "✅ Options noatime ajoutées"
    fi

    # Configuration tmpfs pour logs temporaires (économise SD card)
    if ! grep -q "tmpfs.*log" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0" | sudo tee -a /etc/fstab
        echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,nodev,noexec,size=100m 0 0" | sudo tee -a /etc/fstab
        log "✅ tmpfs configuré pour /tmp et /var/log"
    fi

    # Configuration swappiness pour SSD/SD Card
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
        log "✅ Swappiness configuré à 10"
    fi

    log "✅ Système de fichiers optimisé"
}

# Configuration réseau optimisée
optimize_network() {
    log "Optimisation réseau..."

    # Paramètres réseau pour affichage digital
    cat << 'EOF' | sudo tee /etc/sysctl.d/99-pisignage.conf > /dev/null
# PiSignage v0.8.0 - Optimisations réseau

# Performance réseau
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# TCP optimisations
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# Réduire la latence
net.ipv4.tcp_low_latency = 1
net.core.netdev_max_backlog = 5000

# IPv6 désactivé si non utilisé
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

    log "✅ Configuration réseau optimisée"
}

# Configuration auto-démarrage X11
configure_x11_autostart() {
    log "Configuration auto-démarrage X11..."

    # Configuration pour auto-login
    sudo systemctl set-default graphical.target

    # Configuration lightdm pour auto-login
    if [ -f /etc/lightdm/lightdm.conf ]; then
        sudo tee /etc/lightdm/lightdm.conf > /dev/null << EOF
[Seat:*]
autologin-user=$PISIGNAGE_USER
autologin-user-timeout=0
user-session=LXDE-pi
EOF
        log "✅ Auto-login configuré"
    fi

    # Script de démarrage automatique
    local autostart_dir="/home/$PISIGNAGE_USER/.config/lxsession/LXDE-pi"
    sudo -u $PISIGNAGE_USER mkdir -p "$autostart_dir"

    cat << 'EOF' | sudo -u $PISIGNAGE_USER tee "$autostart_dir/autostart" > /dev/null
# PiSignage v0.8.0 - Auto-démarrage

# Désactiver l'économiseur d'écran
@xset s noblank
@xset s off
@xset -dpms

# Masquer le curseur
@unclutter -idle 0.5 -root

# Démarrer PiSignage (après délai pour laisser le système se stabiliser)
@bash -c 'sleep 10 && /opt/pisignage/scripts/vlc-control.sh start /opt/pisignage/media/default.mp4'
EOF

    log "✅ Auto-démarrage X11 configuré"
}

# Monitoring et logs
setup_monitoring() {
    log "Configuration monitoring..."

    # Script de monitoring système
    cat << 'EOF' | sudo tee /opt/pisignage/scripts/system-monitor.sh > /dev/null
#!/bin/bash

# PiSignage v0.8.0 - Monitoring système

LOG_FILE="/opt/pisignage/logs/system-monitor.log"

log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Informations système
CPU_TEMP=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

log_status "TEMP: ${CPU_TEMP}°C | CPU: ${CPU_USAGE}% | RAM: ${MEMORY_USAGE}% | DISK: ${DISK_USAGE}%"

# Vérification services critiques
services=("nginx" "php8.2-fpm" "pisignage")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_status "SERVICE $service: OK"
    else
        log_status "SERVICE $service: ERROR"
    fi
done

# Alerte si température élevée
if (( $(echo "$CPU_TEMP > 70" | bc -l) )); then
    log_status "WARNING: Température élevée: ${CPU_TEMP}°C"
fi
EOF

    sudo chmod +x /opt/pisignage/scripts/system-monitor.sh

    # Cron job pour monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/pisignage/scripts/system-monitor.sh") | crontab -

    log "✅ Monitoring configuré"
}

# Test des optimisations
test_optimizations() {
    log "Test des optimisations..."

    # Test température CPU
    local temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 | cut -d\' -f1 || echo "N/A")
    info "Température CPU: ${temp}°C"

    # Test mémoire GPU
    local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | cut -d= -f2 || echo "N/A")
    info "Mémoire GPU: $gpu_mem"

    # Test fréquences
    local arm_freq=$(vcgencmd measure_clock arm 2>/dev/null | cut -d= -f2 || echo "N/A")
    local core_freq=$(vcgencmd measure_clock core 2>/dev/null | cut -d= -f2 || echo "N/A")
    info "Fréquence ARM: $((arm_freq/1000000))MHz"
    info "Fréquence Core: $((core_freq/1000000))MHz"

    # Test services essentiels
    local services=("nginx" "php8.2-fpm")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "✅ Service $service actif"
        else
            warn "❌ Service $service inactif"
        fi
    done

    log "✅ Tests terminés"
}

# Fonction principale
main() {
    log "⚡ Optimisation Raspberry Pi pour PiSignage v0.8.0"

    detect_pi_model
    optimize_gpu_memory
    configure_overclocking
    optimize_boot
    disable_unnecessary_services
    optimize_filesystem
    optimize_network
    configure_x11_autostart
    setup_monitoring
    test_optimizations

    echo ""
    log "✅ Optimisation Raspberry Pi terminée!"
    echo ""
    warn "⚠️  REDÉMARRAGE REQUIS pour appliquer toutes les optimisations"
    echo ""
    info "Optimisations appliquées:"
    info "  - GPU memory: $(grep gpu_mem $BOOT_CONFIG | cut -d= -f2)MB"
    info "  - Overclocking: activé selon modèle Pi"
    info "  - Boot: optimisé"
    info "  - Services inutiles: désactivés"
    info "  - Système de fichiers: optimisé"
    info "  - Auto-démarrage X11: configuré"
    echo ""
    info "Monitoring:"
    info "  - Log système: /opt/pisignage/logs/system-monitor.log"
    info "  - Script monitoring: /opt/pisignage/scripts/system-monitor.sh"
    echo ""
    info "Commandes utiles:"
    info "  vcgencmd measure_temp    # Température CPU"
    info "  vcgencmd get_mem gpu     # Mémoire GPU"
    info "  /opt/pisignage/scripts/system-monitor.sh  # Status système"
    echo ""
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi