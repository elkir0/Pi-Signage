#!/usr/bin/env bash

# =============================================================================
# Script de correction des problèmes Chromium Kiosk
# Version: 1.0.0
# Description: Corrige le curseur, la traduction et les images manquantes
# =============================================================================

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Configuration
readonly WEB_ROOT="/var/www/pi-signage"
readonly GITHUB_RAW="https://raw.githubusercontent.com/elkir0/Pi-Signage/main"

# =============================================================================
# FONCTIONS
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# =============================================================================
# CORRECTION DES IMAGES MANQUANTES
# =============================================================================

fix_missing_images() {
    log_info "Correction des images manquantes..."
    
    # Créer les répertoires nécessaires
    mkdir -p "$WEB_ROOT/public/assets/images"
    
    # Télécharger le logo
    if [[ ! -f "$WEB_ROOT/public/assets/images/logo.png" ]]; then
        log_info "Téléchargement du logo..."
        if curl -fsSL "$GITHUB_RAW/web-interface/public/assets/images/logo.png" -o "$WEB_ROOT/public/assets/images/logo.png"; then
            log_info "✓ Logo téléchargé avec succès"
        else
            log_error "✗ Échec du téléchargement du logo"
        fi
    else
        log_info "✓ Logo déjà présent"
    fi
    
    # Télécharger le favicon
    if [[ ! -f "$WEB_ROOT/public/assets/images/favicon.ico" ]]; then
        log_info "Téléchargement du favicon..."
        if curl -fsSL "$GITHUB_RAW/web-interface/public/assets/images/favicon.ico" -o "$WEB_ROOT/public/assets/images/favicon.ico"; then
            log_info "✓ Favicon téléchargé avec succès"
        else
            log_error "✗ Échec du téléchargement du favicon"
        fi
    else
        log_info "✓ Favicon déjà présent"
    fi
    
    # Corriger les permissions
    chown -R www-data:www-data "$WEB_ROOT/public/assets"
    chmod -R 755 "$WEB_ROOT/public/assets"
    
    log_info "Images corrigées"
}

# =============================================================================
# INSTALLATION D'UNCLUTTER
# =============================================================================

install_unclutter() {
    log_info "Installation d'unclutter pour masquer le curseur..."
    
    if ! command -v unclutter >/dev/null 2>&1; then
        if apt-get update && apt-get install -y unclutter; then
            log_info "✓ Unclutter installé"
        else
            log_error "✗ Échec de l'installation d'unclutter"
        fi
    else
        log_info "✓ Unclutter déjà installé"
    fi
}

# =============================================================================
# MISE À JOUR DU SCRIPT CHROMIUM
# =============================================================================

update_chromium_script() {
    log_info "Mise à jour du script Chromium pour améliorer les flags..."
    
    local script="/opt/scripts/chromium-kiosk.sh"
    
    if [[ -f "$script" ]]; then
        # Sauvegarder
        cp "$script" "${script}.bak"
        
        # Ajouter le flag pour désactiver complètement la traduction
        if ! grep -q "disable-features=TranslateUI,Translate" "$script"; then
            sed -i 's/--disable-features=TranslateUI/--disable-features=TranslateUI,Translate/g' "$script"
            log_info "✓ Flags de traduction mis à jour"
        fi
        
        # S'assurer qu'unclutter est configuré correctement
        if grep -q "unclutter -idle 1" "$script"; then
            sed -i 's/unclutter -idle 1/unclutter -idle 0.1 -root/g' "$script"
            log_info "✓ Configuration unclutter mise à jour"
        fi
        
        log_info "Script Chromium mis à jour"
    else
        log_error "Script Chromium introuvable: $script"
    fi
}

# =============================================================================
# MISE À JOUR CSS PLAYER
# =============================================================================

update_player_css() {
    log_info "Mise à jour du CSS pour masquer le curseur..."
    
    local css_file="/var/www/pi-signage-player/css/player.css"
    
    if [[ -f "$css_file" ]]; then
        # Vérifier si la règle existe déjà
        if ! grep -q "cursor: none" "$css_file"; then
            # Ajouter les règles pour masquer le curseur
            echo "" >> "$css_file"
            echo "/* Masquer le curseur */" >> "$css_file"
            echo "* { cursor: none !important; }" >> "$css_file"
            echo "body { cursor: none !important; }" >> "$css_file"
            echo "#video-player { cursor: none !important; }" >> "$css_file"
            
            log_info "✓ CSS mis à jour pour masquer le curseur"
        else
            log_info "✓ CSS déjà configuré pour masquer le curseur"
        fi
    else
        log_warn "Fichier CSS du player introuvable"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== Correction des problèmes Chromium Kiosk ==="
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
    
    # Exécuter les corrections
    fix_missing_images
    install_unclutter
    update_chromium_script
    update_player_css
    
    # Redémarrer Chromium si actif
    if systemctl is-active chromium-kiosk >/dev/null 2>&1; then
        log_info "Redémarrage de Chromium Kiosk..."
        systemctl restart chromium-kiosk
    fi
    
    # Redémarrer Nginx pour appliquer les changements
    if systemctl is-active nginx >/dev/null 2>&1; then
        log_info "Redémarrage de Nginx..."
        systemctl restart nginx
    fi
    
    log_info ""
    log_info "=== Corrections appliquées ==="
    log_info "✓ Images (logo/favicon) corrigées"
    log_info "✓ Unclutter installé pour masquer le curseur"
    log_info "✓ Flags Chromium améliorés"
    log_info "✓ CSS du player mis à jour"
    log_info ""
    log_info "Si le curseur est toujours visible après redémarrage,"
    log_info "vérifiez que le service chromium-kiosk utilise bien le script mis à jour."
}

# Exécution
main "$@"