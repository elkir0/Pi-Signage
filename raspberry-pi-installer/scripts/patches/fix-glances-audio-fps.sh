#!/usr/bin/env bash

# =============================================================================
# Fix pour Glances, Audio et FPS
# Version: 1.0.0
# Description: Corrige les problèmes post-installation v2.4.10
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${GREEN}[FIX]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[FIX]${NC} $*"
}

log_error() {
    echo -e "${RED}[FIX]${NC} $*" >&2
}

# =============================================================================
# 1. FIX GLANCES (404 sur glances.js)
# =============================================================================

fix_glances() {
    log_info "=== Correction de Glances ==="
    
    # Vérifier si Glances est installé
    if ! command -v glances >/dev/null 2>&1; then
        log_error "Glances n'est pas installé!"
        return 1
    fi
    
    # Vérifier la version de Glances
    local version=$(glances --version 2>&1 | grep -oP 'Glances v\K[0-9.]+' || echo "unknown")
    log_info "Version de Glances détectée: $version"
    
    # Le problème vient du fait que Glances web utilise un chemin différent
    # Créer une configuration nginx spécifique pour Glances
    cat > /etc/nginx/sites-available/glances << 'EOF'
server {
    listen 61208;
    listen [::]:61208;
    
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:61209;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Pour les assets statiques
        proxy_buffering off;
    }
}
EOF
    
    # Activer la configuration
    ln -sf /etc/nginx/sites-available/glances /etc/nginx/sites-enabled/
    
    # Modifier le service Glances pour écouter sur un port différent
    log_info "Modification du service Glances..."
    cat > /etc/systemd/system/glances.service << 'EOF'
[Unit]
Description=Glances - System Monitoring
Documentation=man:glances(1)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/glances -w --bind 127.0.0.1 --port 61209 --disable-plugin docker
Restart=on-failure
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Recharger et redémarrer les services
    systemctl daemon-reload
    systemctl restart glances
    nginx -t && systemctl reload nginx
    
    log_info "✓ Glances reconfiguré avec proxy nginx"
}

# =============================================================================
# 2. FIX AUDIO (Pas de son dans les vidéos)
# =============================================================================

fix_audio() {
    log_info "=== Configuration de l'audio ==="
    
    # Vérifier l'état actuel de l'audio
    log_info "État actuel de l'audio:"
    amixer cget numid=3 2>/dev/null || log_warn "Impossible de lire la configuration audio"
    
    # Créer un script de configuration audio interactif
    cat > /opt/scripts/fix-audio-chromium.sh << 'EOF'
#!/bin/bash

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Configuration Audio pour Chromium ===${NC}"
echo

# Détecter la sortie audio actuelle
current=$(amixer cget numid=3 | grep -oP "values=\K[0-9]" || echo "0")
case $current in
    0) current_text="Auto" ;;
    1) current_text="Jack 3.5mm (analogique)" ;;
    2) current_text="HDMI" ;;
    *) current_text="Inconnu" ;;
esac

echo -e "Sortie actuelle: ${YELLOW}$current_text${NC}"
echo
echo "Choisissez la sortie audio:"
echo "1) Jack 3.5mm (sortie casque/haut-parleurs)"
echo "2) HDMI (sortie TV/moniteur)"
echo "3) Auto (détection automatique)"
echo

read -p "Votre choix [1-3]: " choice

case $choice in
    1)
        amixer cset numid=3 1
        echo -e "${GREEN}✓ Audio configuré sur Jack 3.5mm${NC}"
        ;;
    2)
        amixer cset numid=3 2
        echo -e "${GREEN}✓ Audio configuré sur HDMI${NC}"
        ;;
    3)
        amixer cset numid=3 0
        echo -e "${GREEN}✓ Audio configuré sur Auto${NC}"
        ;;
    *)
        echo -e "${RED}Choix invalide${NC}"
        exit 1
        ;;
esac

# Vérifier que PulseAudio est installé pour Chromium
if ! command -v pulseaudio >/dev/null 2>&1; then
    echo -e "${YELLOW}Installation de PulseAudio pour Chromium...${NC}"
    sudo apt-get update
    sudo apt-get install -y pulseaudio pulseaudio-utils
fi

# S'assurer que l'utilisateur pi est dans le groupe audio
sudo usermod -a -G audio pi

# Tester l'audio
echo
echo -e "${YELLOW}Test audio (bip)...${NC}"
speaker-test -t sine -f 1000 -l 1 2>/dev/null || echo -e "${RED}Test audio échoué${NC}"

echo
echo -e "${GREEN}Configuration terminée!${NC}"
echo "Redémarrez le service Chromium pour appliquer les changements:"
echo "sudo systemctl restart chromium-kiosk"
EOF
    
    chmod +x /opt/scripts/fix-audio-chromium.sh
    
    # Installer PulseAudio si nécessaire (requis pour Chromium)
    if ! command -v pulseaudio >/dev/null 2>&1; then
        log_info "Installation de PulseAudio..."
        apt-get update
        apt-get install -y pulseaudio pulseaudio-utils
    fi
    
    # S'assurer que l'audio n'est pas muet
    amixer set Master unmute 2>/dev/null || true
    amixer set Master 75% 2>/dev/null || true
    amixer set PCM unmute 2>/dev/null || true
    amixer set PCM 75% 2>/dev/null || true
    
    log_info "✓ Script de configuration audio créé: /opt/scripts/fix-audio-chromium.sh"
    log_warn "Exécutez le script pour configurer l'audio"
}

# =============================================================================
# 3. FIX PERFORMANCE VIDEO (5-6 FPS)
# =============================================================================

fix_video_performance() {
    log_info "=== Diagnostic performance vidéo ==="
    
    # Vérifier l'accélération GPU
    log_info "Vérification de l'accélération GPU..."
    
    # 1. Vérifier gpu_mem
    local gpu_mem=$(grep "^gpu_mem=" /boot/firmware/config.txt 2>/dev/null | cut -d= -f2 || echo "non défini")
    if [[ "$gpu_mem" == "128" ]]; then
        log_info "✓ gpu_mem=128 correctement configuré"
    else
        log_error "✗ gpu_mem=$gpu_mem (devrait être 128)"
        log_warn "Correction nécessaire dans /boot/firmware/config.txt"
    fi
    
    # 2. Vérifier les codecs
    log_info "Vérification des codecs hardware..."
    for codec in H264 MPG2 WVC1 MPG4 MJPG WMV9; do
        status=$(vcgencmd codec_enabled $codec 2>/dev/null | cut -d= -f2 || echo "error")
        if [[ "$status" == "enabled" ]]; then
            echo -e "  ${GREEN}✓${NC} $codec: enabled"
        else
            echo -e "  ${RED}✗${NC} $codec: $status"
        fi
    done
    
    # 3. Vérifier les devices V4L2
    log_info "Vérification des devices V4L2..."
    if ls /dev/video* 2>/dev/null | grep -q "video1[0-9]"; then
        log_info "✓ Devices V4L2 présents"
        ls -la /dev/video1* 2>/dev/null
    else
        log_error "✗ Devices V4L2 manquants"
    fi
    
    # 4. Créer un script de vérification Chrome GPU
    cat > /opt/scripts/check-chromium-gpu.sh << 'EOF'
#!/bin/bash

echo "=== Vérification GPU dans Chromium ==="
echo
echo "1. Ouvrez Chromium sur le Pi"
echo "2. Allez à: chrome://gpu"
echo "3. Vérifiez que 'Video Decode' est en vert (Hardware accelerated)"
echo
echo "Si ce n'est pas le cas, vérifiez:"
echo "- gpu_mem=128 dans /boot/firmware/config.txt"
echo "- Redémarrage après modification"
echo "- Flags Chromium dans /opt/scripts/chromium-kiosk.sh"
echo
echo "Flags importants pour l'accélération:"
echo "  --use-gl=egl"
echo "  --enable-gpu-rasterization"
echo "  --enable-features=VaapiVideoDecoder"
echo "  --ignore-gpu-blocklist"
EOF
    
    chmod +x /opt/scripts/check-chromium-gpu.sh
    
    # 5. Optimiser le script Chromium si nécessaire
    if [[ -f /opt/scripts/chromium-kiosk.sh ]]; then
        log_info "Vérification des flags Chromium..."
        if ! grep -q "VaapiVideoDecoder" /opt/scripts/chromium-kiosk.sh; then
            log_warn "Flags d'accélération GPU manquants dans chromium-kiosk.sh"
            log_info "Ajout des flags d'optimisation..."
            
            # Sauvegarder l'original
            cp /opt/scripts/chromium-kiosk.sh /opt/scripts/chromium-kiosk.sh.bak
            
            # Chercher la ligne avec les flags et ajouter les optimisations
            sed -i '/--kiosk/a\    --use-gl=egl \\\n    --enable-gpu-rasterization \\\n    --enable-features=VaapiVideoDecoder \\\n    --enable-native-gpu-memory-buffers \\\n    --ignore-gpu-blocklist \\' /opt/scripts/chromium-kiosk.sh
        else
            log_info "✓ Flags d'accélération GPU présents"
        fi
    fi
    
    log_info "✓ Script de vérification GPU créé: /opt/scripts/check-chromium-gpu.sh"
}

# =============================================================================
# 4. DIAGNOSTIC GÉNÉRAL
# =============================================================================

run_diagnostics() {
    log_info "=== Diagnostic système ==="
    
    echo -e "\n${YELLOW}CPU et température:${NC}"
    vcgencmd measure_temp
    echo
    
    echo -e "${YELLOW}Utilisation mémoire:${NC}"
    free -h
    echo
    
    echo -e "${YELLOW}Espace disque:${NC}"
    df -h / /opt/videos
    echo
    
    echo -e "${YELLOW}Services Pi Signage:${NC}"
    systemctl is-active chromium-kiosk || echo "chromium-kiosk: inactive"
    systemctl is-active glances || echo "glances: inactive"
    systemctl is-active nginx || echo "nginx: inactive"
    systemctl is-active php8.2-fpm || echo "php8.2-fpm: inactive"
}

# =============================================================================
# 5. MENU PRINCIPAL
# =============================================================================

main() {
    log_info "=== Fix post-installation Pi Signage v2.4.10 ==="
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Menu
    echo
    echo "Problèmes détectés:"
    echo "1. Glances: erreur 404 sur glances.js"
    echo "2. Audio: pas de son dans les vidéos"  
    echo "3. Performance: vidéos à 5-6 FPS"
    echo "4. Tout corriger"
    echo "5. Diagnostic seulement"
    echo
    
    read -p "Que voulez-vous corriger ? [1-5]: " choice
    
    case $choice in
        1) fix_glances ;;
        2) fix_audio ;;
        3) fix_video_performance ;;
        4) 
            fix_glances
            echo
            fix_audio
            echo
            fix_video_performance
            ;;
        5) run_diagnostics ;;
        *) log_error "Choix invalide" ;;
    esac
    
    echo
    log_info "=== Actions recommandées ==="
    echo
    echo "1. Pour l'audio:"
    echo "   sudo /opt/scripts/fix-audio-chromium.sh"
    echo
    echo "2. Pour les performances vidéo:"
    echo "   - Vérifier gpu_mem=128 dans /boot/firmware/config.txt"
    echo "   - Redémarrer après modification"
    echo "   - Exécuter: /opt/scripts/check-chromium-gpu.sh"
    echo
    echo "3. Pour Glances:"
    echo "   - Accéder à http://[IP]:61208"
    echo "   - Si toujours KO, vérifier les logs: journalctl -u glances -f"
    echo
    echo "4. Redémarrer les services:"
    echo "   sudo systemctl restart chromium-kiosk"
    echo "   sudo systemctl restart glances"
}

main "$@"