#!/usr/bin/env bash

# =============================================================================
# Script de diagnostic pour les problèmes de téléchargement YouTube
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}=== Diagnostic téléchargement YouTube ===${NC}\n"

# 1. Vérifier les logs d'erreur PHP
echo -e "${YELLOW}1. Dernières erreurs PHP :${NC}"
if [ -f /var/log/pi-signage/php-error.log ]; then
    tail -n 20 /var/log/pi-signage/php-error.log | grep -E "(YouTube|yt-dlp|timeout|error)" || echo "Aucune erreur récente liée à YouTube"
else
    echo "Fichier de log PHP non trouvé"
fi

# 2. Vérifier le timeout actuel
echo -e "\n${YELLOW}2. Configuration des timeouts :${NC}"
echo -n "PHP max_execution_time: "
grep -E "max_execution_time|max_input_time" /etc/php/8.2/fpm/pool.d/pi-signage.conf 2>/dev/null || echo "Non défini"
echo -n "Nginx fastcgi_read_timeout: "
grep "fastcgi_read_timeout" /etc/nginx/sites-available/pi-signage 2>/dev/null || echo "Non défini"

# 3. Tester yt-dlp directement
echo -e "\n${YELLOW}3. Test direct de yt-dlp :${NC}"
echo "Test avec une vidéo courte (Me at the zoo - 19 secondes)..."
if sudo -u www-data /opt/scripts/yt-dlp-wrapper.sh \
    -o /tmp/test-download.mp4 \
    "https://www.youtube.com/watch?v=jNQXAC9IVRw" 2>&1; then
    echo -e "${GREEN}✓ Téléchargement réussi${NC}"
    ls -lh /tmp/test-download.mp4 2>/dev/null
    rm -f /tmp/test-download.mp4
else
    echo -e "${RED}✗ Échec du téléchargement${NC}"
fi

# 4. Vérifier les processus bloqués
echo -e "\n${YELLOW}4. Processus yt-dlp/ffmpeg en cours :${NC}"
ps aux | grep -E "(yt-dlp|ffmpeg)" | grep -v grep || echo "Aucun processus trouvé"

# 5. Vérifier l'espace disque
echo -e "\n${YELLOW}5. Espace disque disponible :${NC}"
df -h /opt/videos /tmp /var/www

# 6. Vérifier la mémoire
echo -e "\n${YELLOW}6. Utilisation mémoire :${NC}"
free -h

# 7. Vérifier les permissions
echo -e "\n${YELLOW}7. Permissions des répertoires :${NC}"
ls -ld /opt/videos /tmp/pi-signage-progress /var/www/.cache 2>/dev/null || echo "Certains répertoires manquants"

# 8. Tester le wrapper avec verbose
echo -e "\n${YELLOW}8. Test du wrapper avec sortie détaillée :${NC}"
echo "Exécution : sudo -u www-data /usr/local/bin/yt-dlp --version"
sudo -u www-data /usr/local/bin/yt-dlp --version 2>&1

# 9. Vérifier la configuration PHP pour le streaming
echo -e "\n${YELLOW}9. Configuration PHP pour le streaming :${NC}"
grep -E "(output_buffering|implicit_flush|zlib.output_compression)" /etc/php/8.2/fpm/pool.d/pi-signage.conf 2>/dev/null || echo "Configurations de streaming non trouvées"

# 10. Test de timeout avec une commande longue
echo -e "\n${YELLOW}10. Test de timeout (5 secondes) :${NC}"
if timeout 5 sudo -u www-data bash -c 'echo "Début"; sleep 3; echo "Fin"' 2>&1; then
    echo -e "${GREEN}✓ Pas de problème de timeout${NC}"
else
    echo -e "${RED}✗ Problème de timeout détecté${NC}"
fi

# 11. Vérifier si le wrapper existe et est exécutable
echo -e "\n${YELLOW}11. État du wrapper yt-dlp :${NC}"
if [ -f /opt/scripts/yt-dlp-wrapper.sh ]; then
    echo "✓ Wrapper existe"
    ls -l /opt/scripts/yt-dlp-wrapper.sh
    echo -e "\nPremières lignes du wrapper :"
    head -n 20 /opt/scripts/yt-dlp-wrapper.sh
else
    echo -e "${RED}✗ Wrapper manquant !${NC}"
fi

# 12. Recommandations
echo -e "\n${BLUE}=== Recommandations ===${NC}"
echo
if [ ! -f /opt/scripts/ffmpeg-wrapper.sh ]; then
    echo "- Le wrapper ffmpeg optimisé n'est pas installé"
    echo "  Exécuter : sudo bash /path/to/patches/fix-ffmpeg-verbose.sh"
fi

if ! grep -q "output_buffering" /etc/php/8.2/fpm/pool.d/pi-signage.conf 2>/dev/null; then
    echo "- La configuration PHP pour le streaming n'est pas optimale"
    echo "  Redémarrer PHP-FPM après mise à jour : sudo systemctl restart php8.2-fpm"
fi

echo -e "\n${GREEN}=== Diagnostic terminé ===${NC}"