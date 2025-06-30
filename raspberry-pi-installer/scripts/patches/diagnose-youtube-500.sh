#!/bin/bash

# Script de diagnostic pour l'erreur 500 YouTube
# Ce script identifie la cause exacte de l'erreur

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}=== Diagnostic Erreur 500 API YouTube ===${NC}\n"

# 1. Vérifier les logs PHP
echo -e "${YELLOW}1. Vérification des logs PHP:${NC}"
PHP_ERROR_LOG="/var/log/pi-signage/php-error.log"
if [ -f "$PHP_ERROR_LOG" ]; then
    echo "Dernières erreurs PHP:"
    tail -n 20 "$PHP_ERROR_LOG" | grep -E "(Fatal|Error|Warning)" || echo "  Aucune erreur récente"
else
    echo -e "${RED}  ✗ Log PHP non trouvé${NC}"
fi
echo ""

# 2. Vérifier la configuration PHP
echo -e "${YELLOW}2. Configuration PHP:${NC}"
CONFIG_FILE="/var/www/pi-signage/includes/config.php"
if [ -f "$CONFIG_FILE" ]; then
    echo "  ✓ config.php existe"
    
    # Vérifier YTDLP_BIN
    if grep -q "YTDLP_BIN" "$CONFIG_FILE"; then
        YTDLP_PATH=$(grep "YTDLP_BIN" "$CONFIG_FILE" | cut -d"'" -f4)
        echo "  YTDLP_BIN = $YTDLP_PATH"
        
        # Vérifier si c'est le wrapper
        if [[ "$YTDLP_PATH" == *"wrapper"* ]]; then
            echo -e "${GREEN}  ✓ Utilise le wrapper${NC}"
        else
            echo -e "${RED}  ✗ N'utilise PAS le wrapper${NC}"
        fi
    fi
else
    echo -e "${RED}  ✗ config.php non trouvé${NC}"
fi
echo ""

# 3. Vérifier le wrapper yt-dlp
echo -e "${YELLOW}3. Vérification du wrapper yt-dlp:${NC}"
WRAPPER_PATH="/opt/scripts/yt-dlp-wrapper.sh"
if [ -f "$WRAPPER_PATH" ]; then
    echo -e "${GREEN}  ✓ Wrapper existe${NC}"
    ls -la "$WRAPPER_PATH"
    
    # Tester l'exécution
    echo "  Test d'exécution:"
    if sudo -u www-data sudo "$WRAPPER_PATH" --version 2>&1; then
        echo -e "${GREEN}  ✓ Wrapper fonctionne avec www-data${NC}"
    else
        echo -e "${RED}  ✗ Wrapper ne fonctionne PAS avec www-data${NC}"
    fi
else
    echo -e "${RED}  ✗ Wrapper manquant!${NC}"
fi
echo ""

# 4. Vérifier les permissions sudo
echo -e "${YELLOW}4. Permissions sudo:${NC}"
SUDOERS_FILE="/etc/sudoers.d/pi-signage-web"
if [ -f "$SUDOERS_FILE" ]; then
    echo "  Contenu de $SUDOERS_FILE:"
    grep "yt-dlp-wrapper" "$SUDOERS_FILE" || echo -e "${RED}  ✗ Permission yt-dlp-wrapper manquante${NC}"
else
    echo -e "${RED}  ✗ Fichier sudoers manquant${NC}"
fi
echo ""

# 5. Test direct de l'API
echo -e "${YELLOW}5. Test direct de youtube.php:${NC}"
cd /var/www/pi-signage/api

# Créer un test PHP simple
cat > test-direct.php << 'EOF'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "Test direct de l'API YouTube\n";
echo "PHP Version: " . phpversion() . "\n";
echo "Utilisateur: " . get_current_user() . "\n\n";

// Test des includes
$includes = ['../includes/config.php', '../includes/auth.php', '../includes/functions.php'];
foreach ($includes as $file) {
    if (file_exists($file)) {
        echo "✓ $file existe\n";
        
        // Tester l'inclusion
        try {
            if (!defined('PI_SIGNAGE_WEB')) {
                define('PI_SIGNAGE_WEB', true);
            }
            require_once $file;
            echo "  → Include OK\n";
        } catch (Exception $e) {
            echo "  → ERREUR: " . $e->getMessage() . "\n";
        }
    } else {
        echo "✗ $file MANQUANT\n";
    }
}

// Vérifier les constantes
echo "\nConstantes définies:\n";
if (defined('YTDLP_BIN')) echo "YTDLP_BIN = " . YTDLP_BIN . "\n";
if (defined('VIDEO_DIR')) echo "VIDEO_DIR = " . VIDEO_DIR . "\n";
if (defined('PROGRESS_DIR')) echo "PROGRESS_DIR = " . PROGRESS_DIR . "\n";

// Test d'exécution simple
echo "\nTest d'exécution de commande:\n";
$cmd = "echo 'Test execution'";
exec($cmd, $output, $status);
echo "Status: $status, Output: " . implode("\n", $output) . "\n";
EOF

echo "Exécution du test PHP:"
sudo -u www-data php test-direct.php
rm -f test-direct.php
echo ""

# 6. Vérifier nginx error log
echo -e "${YELLOW}6. Logs nginx:${NC}"
NGINX_ERROR_LOG="/var/log/nginx/error.log"
if [ -f "$NGINX_ERROR_LOG" ]; then
    echo "Dernières erreurs nginx:"
    tail -n 10 "$NGINX_ERROR_LOG" | grep -i "pi-signage" || echo "  Aucune erreur pi-signage"
else
    echo "  Log nginx non trouvé"
fi
echo ""

# 7. Recommandations
echo -e "${BLUE}=== Recommandations ===${NC}"
echo "1. Vérifier les logs PHP pour l'erreur exacte"
echo "2. S'assurer que le wrapper est correctement configuré"
echo "3. Vérifier que config.php utilise le bon chemin YTDLP_BIN"
echo "4. Tester avec: curl -X POST http://localhost/api/youtube.php -d '{\"url\":\"test\"}'"
echo ""

# Créer un rapport
REPORT_FILE="/tmp/youtube-500-diagnostic-$(date +%Y%m%d_%H%M%S).txt"
echo "Rapport complet sauvegardé dans: $REPORT_FILE"