#!/usr/bin/env bash

# =============================================================================
# Corrections essentielles pour Pi Signage v2.4.9
# Version: 1.0.0
# Description: Intègre les corrections critiques pour un nouveau déploiement
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[FIX]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[FIX]${NC} $*"; }
log_error() { echo -e "${RED}[FIX]${NC} $*" >&2; }

# =============================================================================
# 1. FIX PERMISSIONS DES LOGS
# =============================================================================

fix_log_permissions() {
    log_info "Correction des permissions des logs..."
    
    # Créer les répertoires de logs avec les bonnes permissions
    mkdir -p /var/log/pi-signage
    chown -R pi:pi /var/log/pi-signage
    chmod 755 /var/log/pi-signage
    
    # Créer les fichiers de log s'ils n'existent pas
    local log_files=(
        "chromium.log"
        "startup.log"
        "sync.log"
        "health.log"
        "php-error.log"
        "playlist-update.log"
        "ytdlp-update.log"
        "web-update.log"
    )
    
    for log_file in "${log_files[@]}"; do
        touch "/var/log/pi-signage/$log_file"
        chown pi:pi "/var/log/pi-signage/$log_file"
        chmod 644 "/var/log/pi-signage/$log_file"
    done
    
    # Créer aussi le répertoire pour www-data
    mkdir -p /var/log/pi-signage/www-data
    chown www-data:www-data /var/log/pi-signage/www-data
    chmod 755 /var/log/pi-signage/www-data
    
    log_info "✓ Permissions des logs corrigées"
}

# =============================================================================
# 2. VÉRIFICATION GPU_MEM
# =============================================================================

check_gpu_mem() {
    log_info "Vérification de gpu_mem..."
    
    local boot_path="/boot"
    [[ -d "/boot/firmware" ]] && boot_path="/boot/firmware"
    
    if grep -q "^gpu_mem=128" "$boot_path/config.txt" 2>/dev/null; then
        log_info "✓ gpu_mem=128 déjà configuré"
    else
        log_warn "gpu_mem non configuré à 128MB"
        log_info "Pour de meilleures performances vidéo, ajoutez à $boot_path/config.txt :"
        log_info "  gpu_mem=128"
    fi
}

# =============================================================================
# 3. FIX SERVICE CHROMIUM
# =============================================================================

fix_chromium_service() {
    log_info "Vérification du service Chromium..."
    
    # Corriger les permissions dans le service systemd
    if [[ -f /etc/systemd/system/chromium-kiosk.service ]]; then
        # S'assurer que le service utilise bien l'utilisateur pi
        if ! grep -q "^User=pi" /etc/systemd/system/chromium-kiosk.service; then
            log_warn "Service Chromium ne spécifie pas User=pi"
            sed -i '/\[Service\]/a User=pi\nGroup=pi' /etc/systemd/system/chromium-kiosk.service
        fi
        
        # Ajouter les variables d'environnement nécessaires
        if ! grep -q "^Environment=\"HOME=" /etc/systemd/system/chromium-kiosk.service; then
            sed -i '/\[Service\]/a Environment="HOME=/home/pi"' /etc/systemd/system/chromium-kiosk.service
        fi
        
        systemctl daemon-reload
        log_info "✓ Service Chromium vérifié"
    fi
}

# =============================================================================
# 4. CONFIGURATION NGINX POUR GLANCES
# =============================================================================

fix_glances_nginx() {
    log_info "Configuration Nginx pour Glances..."
    
    # Vérifier si la config existe
    if [[ -f /etc/nginx/sites-available/pi-signage ]]; then
        # Vérifier si le proxy Glances est configuré
        if ! grep -q "location /glances" /etc/nginx/sites-available/pi-signage; then
            log_warn "Ajout de la configuration proxy pour Glances..."
            
            # Ajouter avant la dernière accolade fermante
            sed -i '/^}$/i \
    # Proxy pour Glances\
    location /glances/ {\
        proxy_pass http://localhost:61208/;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
    }' /etc/nginx/sites-available/pi-signage
            
            nginx -t && systemctl reload nginx
            log_info "✓ Configuration Glances ajoutée"
        else
            log_info "✓ Configuration Glances déjà présente"
        fi
    fi
}

# =============================================================================
# 5. CRÉER RÉPERTOIRES MANQUANTS
# =============================================================================

create_missing_dirs() {
    log_info "Création des répertoires manquants..."
    
    # Répertoires nécessaires
    local -A directories=(
        ["/opt/videos"]="www-data:www-data:755"
        ["/opt/scripts"]="root:root:755"
        ["/var/cache/chromium-kiosk"]="pi:pi:755"
        ["/var/www/.cache"]="www-data:www-data:755"
        ["/tmp/pi-signage-progress"]="root:root:777"
    )
    
    for dir in "${!directories[@]}"; do
        IFS=':' read -r owner group perms <<< "${directories[$dir]}"
        
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chown "$owner:$group" "$dir"
            chmod "$perms" "$dir"
            log_info "✓ Créé: $dir"
        fi
    done
}

# =============================================================================
# 6. VÉRIFICATIONS FINALES
# =============================================================================

final_checks() {
    log_info "=== Vérifications finales ==="
    
    local issues=0
    
    # Vérifier les services critiques
    for service in nginx php8.2-fpm; do
        if systemctl is-active --quiet $service; then
            echo -e "${GREEN}✓${NC} $service actif"
        else
            echo -e "${RED}✗${NC} $service inactif"
            ((issues++))
        fi
    done
    
    # Vérifier les permissions des logs
    if [[ -w /var/log/pi-signage/chromium.log ]]; then
        echo -e "${GREEN}✓${NC} Logs accessibles en écriture"
    else
        echo -e "${RED}✗${NC} Problème de permissions sur les logs"
        ((issues++))
    fi
    
    # Vérifier les wrappers
    for wrapper in yt-dlp-wrapper.sh ffmpeg-wrapper.sh; do
        if [[ -x "/opt/scripts/$wrapper" ]]; then
            echo -e "${GREEN}✓${NC} $wrapper présent et exécutable"
        else
            echo -e "${RED}✗${NC} $wrapper manquant"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log_info "✓ Toutes les vérifications sont passées"
    else
        log_warn "$issues problème(s) détecté(s)"
    fi
    
    return $issues
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en root"
        exit 1
    fi
    
    log_info "=== Application des corrections essentielles ==="
    echo
    
    # Appliquer les corrections
    fix_log_permissions
    check_gpu_mem
    fix_chromium_service
    fix_glances_nginx
    create_missing_dirs
    
    echo
    final_checks
    
    echo
    log_info "=== Corrections terminées ==="
    echo
    log_info "Actions recommandées :"
    echo "1. Redémarrer les services :"
    echo "   systemctl restart nginx php8.2-fpm"
    echo "   systemctl restart chromium-kiosk"
    echo
    echo "2. Si gpu_mem n'est pas configuré :"
    echo "   Ajouter 'gpu_mem=128' dans /boot/config.txt et redémarrer"
    echo
    echo "3. Pour un déploiement neuf :"
    echo "   Ce script a préparé le système pour une installation propre"
}

main "$@"