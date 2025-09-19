#!/bin/bash
# =============================================================================
# Configuration Système Optimale pour Digital Signage Pi 4
# Basé sur les success stories et meilleures pratiques 2024/2025
# =============================================================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
BACKUP_DIR="/opt/pisignage/backups/$(date +%Y%m%d_%H%M%S)"

echo -e "${GREEN}=== CONFIGURATION SYSTÈME OPTIMALE - RASPBERRY PI 4 ===${NC}"
echo "Digital Signage avec GPU Acceleration"
echo "Basé sur les success stories communautaires"
echo ""

# Vérifications préliminaires
echo -e "${YELLOW}1. Vérifications système...${NC}"

# Vérifier Pi 4
PI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
if [[ ! "$PI_MODEL" =~ "Raspberry Pi 4" ]]; then
    echo "⚠️  Attention: Ce script est optimisé pour Raspberry Pi 4"
    echo "   Modèle détecté: $PI_MODEL"
    read -p "Continuer quand même? [y/N]: " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# Vérifier Bookworm
OS_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
if [[ "$OS_VERSION" != "12" ]]; then
    echo "⚠️  Attention: Script optimisé pour Bookworm (Debian 12)"
    echo "   Version détectée: $OS_VERSION"
fi

echo "✓ Raspberry Pi 4 détecté: $PI_MODEL"
echo "✓ OS: $(lsb_release -ds 2>/dev/null || echo "Non détecté")"
echo "✓ Kernel: $(uname -r)"

# Créer backup
mkdir -p "$BACKUP_DIR"
echo "✓ Backup créé: $BACKUP_DIR"

# Menu de configuration
echo ""
echo "Choisissez la configuration:"
echo "1) Configuration complète (recommandé)"
echo "2) GPU et performance seulement"
echo "3) Chromium optimisé seulement"
echo "4) Wayland/X11 optimisation"
echo "5) Kiosk mode setup"
echo "6) Diagnostic et vérification"
echo ""
read -p "Choix [1-6]: " choice

# Fonction backup
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
        echo "  📄 Backup: $(basename "$file")"
    fi
}

# Configuration GPU et Performance
configure_gpu_performance() {
    echo -e "${BLUE}=== CONFIGURATION GPU ET PERFORMANCE ===${NC}"
    
    # Backup config files
    backup_file "/boot/firmware/config.txt"
    backup_file "/boot/config.txt"
    
    # Détecter le fichier config
    CONFIG_FILE=""
    if [ -f "/boot/firmware/config.txt" ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
    elif [ -f "/boot/config.txt" ]; then
        CONFIG_FILE="/boot/config.txt"
    else
        echo "❌ Fichier config.txt non trouvé"
        return 1
    fi
    
    echo "🔧 Configuration $CONFIG_FILE..."
    
    # GPU Memory (optionnel sur Bookworm mais peut aider)
    if ! grep -q "gpu_mem=" "$CONFIG_FILE"; then
        echo "gpu_mem=128" | sudo tee -a "$CONFIG_FILE" >/dev/null
        echo "✓ GPU memory: 128MB"
    fi
    
    # HDMI force hotplug pour stabilité
    if ! grep -q "hdmi_force_hotplug=1" "$CONFIG_FILE"; then
        echo "hdmi_force_hotplug=1" | sudo tee -a "$CONFIG_FILE" >/dev/null
        echo "✓ HDMI force hotplug activé"
    fi
    
    # Overclock modéré pour performance (optionnel)
    read -p "Activer overclock modéré pour meilleures performances? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! grep -q "arm_freq=1800" "$CONFIG_FILE"; then
            {
                echo "# Overclock modéré pour performance"
                echo "arm_freq=1800"
                echo "gpu_freq=600"
                echo "over_voltage=4"
            } | sudo tee -a "$CONFIG_FILE" >/dev/null
            echo "✓ Overclock modéré activé"
        fi
    fi
    
    # Configuration système
    echo ""
    echo "🔧 Configuration système performance..."
    
    # Limites système pour GPU
    sudo tee /etc/security/limits.d/gpu.conf << 'EOF' >/dev/null
# GPU performance limits
* soft memlock unlimited
* hard memlock unlimited
EOF
    echo "✓ Limites mémoire GPU configurées"
    
    # Swappiness pour performance avec SSD
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf >/dev/null
        echo "✓ Swappiness réduite (SSD friendly)"
    fi
    
    echo "✓ Configuration GPU et performance terminée"
}

# Configuration Chromium
configure_chromium() {
    echo -e "${BLUE}=== CONFIGURATION CHROMIUM OPTIMISÉE ===${NC}"
    
    # Installation Chromium si nécessaire
    if ! command -v chromium-browser >/dev/null; then
        echo "📦 Installation Chromium..."
        sudo apt update
        sudo apt install -y chromium-browser
    fi
    
    # Configuration flags GPU
    echo "🔧 Configuration flags Chromium GPU..."
    sudo mkdir -p /etc/chromium.d
    
    backup_file "/etc/chromium.d/00-rpi-gpu"
    
    sudo tee /etc/chromium.d/00-rpi-gpu << 'EOF' >/dev/null
# Flags GPU optimaux pour Raspberry Pi 4 - 2024/2025
# Basés sur success stories communautaires

export CHROMIUM_FLAGS="\
--use-angle=gles \
--use-gl=egl \
--enable-gpu-rasterization \
--enable-native-gpu-memory-buffers \
--ignore-gpu-blocklist \
--enable-zero-copy \
--enable-accelerated-video-decode \
--enable-features=VaapiVideoDecoder \
--disable-features=UseChromeOSDirectVideoDecoder \
--autoplay-policy=no-user-gesture-required \
--disable-background-timer-throttling \
--disable-backgrounding-occluded-windows \
--disable-renderer-backgrounding \
--aggressive-cache-discard \
--max-active-webgl-contexts=2"
EOF
    
    echo "✓ Flags Chromium GPU configurés"
    
    # Script kiosk optimisé
    echo "🔧 Création script kiosk optimisé..."
    
    cat > ~/chromium-kiosk.sh << 'EOF'
#!/bin/bash
# Chromium Kiosk Optimisé pour Digital Signage Pi 4

# Variables
export DISPLAY=:0
export XAUTHORITY=$HOME/.Xauthority
URL="${1:-file:///home/pi/signage.html}"

# Attendre que le display soit prêt
sleep 3

# Désactiver économiseur d'écran
xset s off -dpms s noblank 2>/dev/null || true

# Cacher curseur
if command -v unclutter >/dev/null; then
    unclutter -idle 0.5 -root &
fi

# Tuer instances Chromium existantes
pkill -f chromium-browser || true
sleep 2

# Logs
mkdir -p ~/logs
LOG_FILE="~/logs/chromium-$(date +%Y%m%d).log"

# Lancement Chromium avec GPU optimal
exec chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --check-for-update-interval=31536000 \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --use-angle=gles \
    --use-gl=egl \
    --enable-gpu-rasterization \
    --enable-native-gpu-memory-buffers \
    --ignore-gpu-blocklist \
    --enable-zero-copy \
    --enable-accelerated-video-decode \
    --enable-features=VaapiVideoDecoder \
    --disable-features=UseChromeOSDirectVideoDecoder \
    --autoplay-policy=no-user-gesture-required \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --aggressive-cache-discard \
    --max-active-webgl-contexts=2 \
    "$URL" \
    >> "$LOG_FILE" 2>&1
EOF
    
    chmod +x ~/chromium-kiosk.sh
    echo "✓ Script kiosk créé: ~/chromium-kiosk.sh"
    
    # Page de test par défaut
    cat > ~/signage.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Digital Signage Ready</title>
    <style>
        body { margin: 0; background: linear-gradient(45deg, #1a1a2e, #16213e); 
               color: white; font-family: Arial; display: flex; 
               justify-content: center; align-items: center; height: 100vh; }
        .container { text-align: center; }
        .logo { font-size: 4em; margin-bottom: 20px; }
        .status { font-size: 1.5em; color: #4CAF50; margin: 10px 0; }
        .info { font-size: 1em; color: #ccc; margin: 5px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <div class="status">Digital Signage Ready</div>
        <div class="info">Raspberry Pi 4 avec GPU Acceleration</div>
        <div class="info">Chromium Optimisé - Bookworm</div>
        <div class="info">Remplacez ce fichier par votre contenu</div>
        <div id="time" style="margin-top: 20px; font-size: 1.2em;"></div>
    </div>
    <script>
        setInterval(() => {
            document.getElementById('time').textContent = new Date().toLocaleString('fr-FR');
        }, 1000);
    </script>
</body>
</html>
EOF
    
    echo "✓ Page de test créée: ~/signage.html"
    
    echo "✓ Configuration Chromium terminée"
}

# Configuration Wayland/X11
configure_display() {
    echo -e "${BLUE}=== CONFIGURATION DISPLAY (WAYLAND/X11) ===${NC}"
    
    echo "Display actuel: ${XDG_SESSION_TYPE:-"Non détecté"}"
    
    echo "Options disponibles:"
    echo "1) Wayland + labwc (recommandé pour GPU)"
    echo "2) X11 (compatibilité)"
    echo "3) Auto-détection optimale"
    echo ""
    read -p "Choix [1-3]: " display_choice
    
    case $display_choice in
        1)
            echo "🔧 Configuration Wayland + labwc..."
            sudo raspi-config nonint do_wayland W1
            echo "✓ Wayland activé (redémarrage requis)"
            ;;
        2)
            echo "🔧 Configuration X11..."
            sudo raspi-config nonint do_wayland W2
            echo "✓ X11 activé (redémarrage requis)"
            ;;
        3)
            echo "🔧 Configuration auto-détection..."
            # Garder la configuration actuelle si elle fonctionne
            if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
                echo "✓ Wayland déjà actif - conservé"
            else
                echo "✓ Configuration actuelle conservée"
            fi
            ;;
    esac
    
    # Installation utilitaires display
    sudo apt install -y mesa-utils unclutter xserver-xorg-utils
    echo "✓ Utilitaires display installés"
}

# Configuration Kiosk Mode
configure_kiosk() {
    echo -e "${BLUE}=== CONFIGURATION KIOSK MODE ===${NC}"
    
    # Autologin
    echo "🔧 Configuration autologin..."
    sudo raspi-config nonint do_boot_behaviour B4
    echo "✓ Autologin activé"
    
    # Service systemd pour kiosk
    echo "🔧 Création service kiosk..."
    
    backup_file "/etc/systemd/system/kiosk.service"
    
    sudo tee /etc/systemd/system/kiosk.service << 'EOF' >/dev/null
[Unit]
Description=Digital Signage Kiosk
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStartPre=/bin/sleep 10
ExecStart=/home/pi/chromium-kiosk.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
EOF
    
    sudo systemctl daemon-reload
    echo "✓ Service kiosk créé"
    
    read -p "Activer le service kiosk au démarrage? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl enable kiosk.service
        echo "✓ Service kiosk activé"
    fi
    
    # Desktop autostart en backup
    echo "🔧 Configuration desktop autostart (backup)..."
    mkdir -p ~/.config/autostart
    
    cat > ~/.config/autostart/kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Digital Signage Kiosk
Comment=Chromium Kiosk for Digital Signage
Exec=/home/pi/chromium-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    
    echo "✓ Desktop autostart configuré"
}

# Diagnostic système
diagnostic_system() {
    echo -e "${BLUE}=== DIAGNOSTIC SYSTÈME ===${NC}"
    
    echo "📊 Informations système:"
    echo "  Modèle: $(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Non détecté")"
    echo "  OS: $(lsb_release -ds 2>/dev/null || echo "Non détecté")"
    echo "  Kernel: $(uname -r)"
    echo "  Desktop: ${XDG_SESSION_TYPE:-"Non détecté"}"
    echo ""
    
    echo "🔧 GPU Status:"
    vcgencmd measure_temp
    vcgencmd get_throttled | awk '/throttled/ {
        val=strtonum($0); 
        if(val==0) print "  ✓ Throttling: Aucun";
        else print "  ⚠ Throttling détecté: " val;
    }'
    vcgencmd get_mem gpu | sed 's/^/  /'
    vcgencmd get_mem arm | sed 's/^/  /'
    vcgencmd measure_clock core | awk -F= '{printf "  GPU Clock: %.0f MHz\n", $2/1000000}'
    echo ""
    
    echo "🎮 OpenGL/Mesa Info:"
    if command -v glxinfo >/dev/null; then
        glxinfo | grep -E "(OpenGL version|OpenGL renderer)" | sed 's/^/  /'
    else
        echo "  ⚠ glxinfo non disponible (installez mesa-utils)"
    fi
    echo ""
    
    echo "🌐 Chromium Configuration:"
    if [ -f "/etc/chromium.d/00-rpi-gpu" ]; then
        echo "  ✓ Configuration GPU trouvée"
    else
        echo "  ⚠ Configuration GPU manquante"
    fi
    
    if command -v chromium-browser >/dev/null; then
        echo "  ✓ Chromium installé: $(chromium-browser --version 2>/dev/null | head -1 || echo "Version non détectée")"
    else
        echo "  ❌ Chromium non installé"
    fi
    echo ""
    
    echo "🔄 Services:"
    if systemctl is-enabled kiosk.service >/dev/null 2>&1; then
        echo "  ✓ Service kiosk: $(systemctl is-active kiosk.service)"
    else
        echo "  ⚠ Service kiosk non configuré"
    fi
    echo ""
    
    echo "📁 Fichiers configuration:"
    [ -f ~/chromium-kiosk.sh ] && echo "  ✓ Script kiosk: ~/chromium-kiosk.sh" || echo "  ⚠ Script kiosk manquant"
    [ -f ~/signage.html ] && echo "  ✓ Page test: ~/signage.html" || echo "  ⚠ Page test manquante"
    echo ""
    
    echo "🧪 Test rapide GPU:"
    timeout 5 chromium-browser --headless --enable-gpu-benchmarking \
        --run-all-compositor-stages-before-draw \
        --disable-web-security \
        about:blank >/dev/null 2>&1 && echo "  ✓ Chromium GPU: OK" || echo "  ⚠ Chromium GPU: Problème"
}

# Exécution selon choix
case $choice in
    1)
        echo "🚀 Configuration complète..."
        configure_gpu_performance
        echo ""
        configure_chromium  
        echo ""
        configure_display
        echo ""
        configure_kiosk
        ;;
    2)
        configure_gpu_performance
        ;;
    3)
        configure_chromium
        ;;
    4)
        configure_display
        ;;
    5)
        configure_kiosk
        ;;
    6)
        diagnostic_system
        exit 0
        ;;
    *)
        echo "❌ Choix invalide"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== CONFIGURATION TERMINÉE ===${NC}"
echo ""
echo "📄 Backups créés dans: $BACKUP_DIR"
echo "🚀 Script kiosk: ~/chromium-kiosk.sh"
echo "📺 Page test: ~/signage.html"
echo ""
echo "🔧 Commandes utiles:"
echo "  Test manuel: ~/chromium-kiosk.sh"
echo "  Service: sudo systemctl start kiosk.service"
echo "  Logs: journalctl -u kiosk.service -f"
echo "  Diagnostic: $0 [choix 6]"
echo ""

# Redémarrage requis?
if grep -q "gpu_mem\|arm_freq\|hdmi_force" "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Redémarrage recommandé pour appliquer les changements config.txt${NC}"
    read -p "Redémarrer maintenant? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
fi

echo "✅ Configuration système optimale terminée!"
echo "📋 Voir aussi: /opt/pisignage/SOLUTIONS_GPU_CHROMIUM_PI4.md"