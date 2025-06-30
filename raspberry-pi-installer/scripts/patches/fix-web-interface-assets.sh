#!/usr/bin/env bash

# =============================================================================
# Patch - Correction des assets de l'interface web
# Version: 1.0.0
# Description: Corrige les problèmes d'assets et de fonctions dupliquées
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Configuration
readonly WEB_ROOT="/var/www/pi-signage"

echo -e "${YELLOW}=== Correction des assets de l'interface web ===${NC}"

# 1. Supprimer la fonction logActivity dupliquée si elle existe
if grep -q "function logActivity" "$WEB_ROOT/includes/functions.php" 2>/dev/null; then
    echo "Suppression de la fonction logActivity dupliquée..."
    # Faire une sauvegarde
    cp "$WEB_ROOT/includes/functions.php" "$WEB_ROOT/includes/functions.php.bak"
    
    # Supprimer la fonction (en utilisant awk pour plus de précision)
    awk '
    /^\/\*\*$/ && /Logger une activité/ { skip=1 }
    /^}$/ && skip { skip=0; next }
    !skip
    ' "$WEB_ROOT/includes/functions.php" > "$WEB_ROOT/includes/functions.php.tmp"
    
    mv "$WEB_ROOT/includes/functions.php.tmp" "$WEB_ROOT/includes/functions.php"
    chown www-data:www-data "$WEB_ROOT/includes/functions.php"
    echo -e "${GREEN}✓ Fonction dupliquée supprimée${NC}"
fi

# 2. Créer les liens symboliques pour les assets
echo "Création des liens pour les assets..."

# Créer les répertoires si nécessaire
mkdir -p "$WEB_ROOT/public/assets/"{css,js,images}

# Créer les liens pour CSS
if [[ -f "$WEB_ROOT/assets/css/style.css" ]] && [[ ! -L "$WEB_ROOT/public/assets/css/style.css" ]]; then
    ln -sf "$WEB_ROOT/assets/css/style.css" "$WEB_ROOT/public/assets/css/style.css"
    echo -e "${GREEN}✓ Lien créé pour style.css${NC}"
fi

if [[ -f "$WEB_ROOT/assets/css/dashboard.css" ]] && [[ ! -L "$WEB_ROOT/public/assets/css/dashboard.css" ]]; then
    ln -sf "$WEB_ROOT/assets/css/dashboard.css" "$WEB_ROOT/public/assets/css/dashboard.css"
    echo -e "${GREEN}✓ Lien créé pour dashboard.css${NC}"
fi

# Créer les liens pour JS
if [[ -f "$WEB_ROOT/assets/js/main.js" ]] && [[ ! -L "$WEB_ROOT/public/assets/js/main.js" ]]; then
    ln -sf "$WEB_ROOT/assets/js/main.js" "$WEB_ROOT/public/assets/js/main.js"
    echo -e "${GREEN}✓ Lien créé pour main.js${NC}"
fi

# 3. Corriger les permissions
echo "Correction des permissions..."
chown -R www-data:www-data "$WEB_ROOT/public/assets"
chmod -R 755 "$WEB_ROOT/public/assets"

# 4. Redémarrer PHP-FPM pour appliquer les changements
echo "Redémarrage de PHP-FPM..."
systemctl restart php8.2-fpm

echo
echo -e "${GREEN}✓ Corrections appliquées avec succès !${NC}"
echo "Testez l'interface web pour vérifier que tout fonctionne."