#!/usr/bin/env bash

# =============================================================================
# Fix pour le problème de timeout YouTube (error code 124)
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
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
# ANALYSE DU PROBLÈME
# =============================================================================

log_info "=== Analyse du problème de timeout YouTube ==="
echo
log_warn "Erreur détectée : timeout 300 (code retour 124)"
log_warn "Cela signifie que la commande a été tuée après 5 minutes"
echo

# =============================================================================
# 1. VÉRIFIER ET CORRIGER LE WRAPPER
# =============================================================================

fix_wrapper() {
    log_info "Correction du wrapper yt-dlp-wrapper.sh..."
    
    # Créer une version sans le timeout de 300 secondes
    cat > /opt/scripts/yt-dlp-wrapper-notimeout.sh << 'EOF'
#!/bin/bash
# Wrapper pour yt-dlp SANS timeout pour debug

# Définir l'environnement
export HOME=/var/www
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONIOENCODING=utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Log de début
echo "[$(date)] Début du téléchargement YouTube" >&2

# Créer le répertoire cache si nécessaire
mkdir -p /var/www/.cache/yt-dlp 2>/dev/null
chmod 755 /var/www/.cache 2>/dev/null
chown -R www-data:www-data /var/www/.cache 2>/dev/null

# Exécuter yt-dlp avec les arguments
exec /usr/local/bin/yt-dlp \
    --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
    --merge-output-format mp4 \
    --verbose \
    --progress \
    --newline \
    "$@"
EOF
    
    chmod 755 /opt/scripts/yt-dlp-wrapper-notimeout.sh
    
    # Mettre à jour les permissions sudo
    if ! grep -q "yt-dlp-wrapper-notimeout.sh" /etc/sudoers.d/pi-signage-web 2>/dev/null; then
        echo "www-data ALL=(ALL) NOPASSWD: /opt/scripts/yt-dlp-wrapper-notimeout.sh" >> /etc/sudoers.d/pi-signage-web
    fi
    
    log_info "✓ Wrapper sans timeout créé"
}

# =============================================================================
# 2. IDENTIFIER LA SOURCE DU TIMEOUT
# =============================================================================

check_timeout_source() {
    log_info "Recherche de la source du timeout..."
    
    # Chercher dans les fichiers PHP
    echo -e "\n${YELLOW}Recherche dans les fichiers PHP :${NC}"
    if [ -d /var/www/pi-signage ]; then
        grep -r "timeout 300" /var/www/pi-signage/ 2>/dev/null || true
        grep -r "timeout.*300" /var/www/pi-signage/ 2>/dev/null || true
    fi
    
    # Le problème vient probablement du code PHP qui appelle :
    # timeout 300 sudo /opt/scripts/yt-dlp-wrapper.sh ...
    
    log_warn "Le timeout de 300 secondes est probablement défini dans le code PHP"
}

# =============================================================================
# 3. CRÉER UN WRAPPER AVEC GESTION DU TIMEOUT INTELLIGENTE
# =============================================================================

create_smart_wrapper() {
    log_info "Création d'un wrapper intelligent..."
    
    cat > /opt/scripts/yt-dlp-smart-wrapper.sh << 'EOF'
#!/bin/bash
# Wrapper intelligent pour yt-dlp avec gestion du timeout

# Configuration
MAX_DOWNLOAD_TIME=1800  # 30 minutes max
PROGRESS_FILE="/tmp/yt-dlp-progress-$$.txt"
PID_FILE="/tmp/yt-dlp-pid-$$.txt"

# Nettoyage en sortie
cleanup() {
    rm -f "$PROGRESS_FILE" "$PID_FILE" 2>/dev/null
    if [ -n "$YT_PID" ]; then
        kill $YT_PID 2>/dev/null
    fi
}
trap cleanup EXIT

# Environnement
export HOME=/var/www
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONIOENCODING=utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Créer les répertoires nécessaires
mkdir -p /var/www/.cache/yt-dlp /tmp/pi-signage-progress 2>/dev/null
chmod 755 /var/www/.cache /tmp/pi-signage-progress 2>/dev/null
chown -R www-data:www-data /var/www/.cache 2>/dev/null

# Démarrer yt-dlp en arrière-plan
/usr/local/bin/yt-dlp \
    --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
    --merge-output-format mp4 \
    --progress \
    --newline \
    --no-color \
    --progress-template "download:[download] %(progress._percent_str)s of %(progress._total_bytes_str)s at %(progress._speed_str)s ETA %(progress._eta_str)s" \
    "$@" > "$PROGRESS_FILE" 2>&1 &

YT_PID=$!
echo $YT_PID > "$PID_FILE"

# Surveiller le processus
ELAPSED=0
while kill -0 $YT_PID 2>/dev/null; do
    # Afficher la dernière ligne de progression
    if [ -f "$PROGRESS_FILE" ]; then
        tail -n 1 "$PROGRESS_FILE" 2>/dev/null || true
    fi
    
    # Vérifier le timeout
    if [ $ELAPSED -ge $MAX_DOWNLOAD_TIME ]; then
        echo "[ERROR] Timeout atteint après $MAX_DOWNLOAD_TIME secondes" >&2
        kill $YT_PID 2>/dev/null
        exit 124
    fi
    
    sleep 1
    ((ELAPSED++))
done

# Récupérer le code de sortie
wait $YT_PID
EXIT_CODE=$?

# Afficher les dernières lignes en cas d'erreur
if [ $EXIT_CODE -ne 0 ]; then
    echo "[ERROR] yt-dlp a échoué avec le code: $EXIT_CODE" >&2
    tail -n 10 "$PROGRESS_FILE" 2>/dev/null || true
fi

exit $EXIT_CODE
EOF
    
    chmod 755 /opt/scripts/yt-dlp-smart-wrapper.sh
    
    # Ajouter aux permissions sudo
    if ! grep -q "yt-dlp-smart-wrapper.sh" /etc/sudoers.d/pi-signage-web 2>/dev/null; then
        echo "www-data ALL=(ALL) NOPASSWD: /opt/scripts/yt-dlp-smart-wrapper.sh" >> /etc/sudoers.d/pi-signage-web
    fi
    
    log_info "✓ Wrapper intelligent créé"
}

# =============================================================================
# 4. TESTER LES WRAPPERS
# =============================================================================

test_wrappers() {
    log_info "Test des wrappers..."
    
    local test_url="https://www.youtube.com/watch?v=jNQXAC9IVRw"  # Vidéo de 19 secondes
    
    echo -e "\n${YELLOW}Test 1: Wrapper original avec timeout${NC}"
    if timeout 10 sudo -u www-data /opt/scripts/yt-dlp-wrapper.sh -o /tmp/test1.mp4 "$test_url" 2>&1; then
        echo -e "${GREEN}✓ Succès${NC}"
        rm -f /tmp/test1.mp4
    else
        echo -e "${RED}✗ Échec (code: $?)${NC}"
    fi
    
    echo -e "\n${YELLOW}Test 2: Wrapper sans timeout${NC}"
    if sudo -u www-data /opt/scripts/yt-dlp-wrapper-notimeout.sh -o /tmp/test2.mp4 "$test_url" 2>&1; then
        echo -e "${GREEN}✓ Succès${NC}"
        rm -f /tmp/test2.mp4
    else
        echo -e "${RED}✗ Échec (code: $?)${NC}"
    fi
    
    echo -e "\n${YELLOW}Test 3: Wrapper intelligent${NC}"
    if sudo -u www-data /opt/scripts/yt-dlp-smart-wrapper.sh -o /tmp/test3.mp4 "$test_url" 2>&1; then
        echo -e "${GREEN}✓ Succès${NC}"
        rm -f /tmp/test3.mp4
    else
        echo -e "${RED}✗ Échec (code: $?)${NC}"
    fi
}

# =============================================================================
# 5. RECOMMANDATIONS
# =============================================================================

show_recommendations() {
    echo
    log_info "=== Recommandations ==="
    echo
    echo "1. Le problème vient du 'timeout 300' dans le code PHP"
    echo "   - Chercher dans youtube.php ou l'API YouTube"
    echo "   - Remplacer par un timeout plus long ou retirer le timeout"
    echo
    echo "2. Solutions possibles :"
    echo "   a) Augmenter le timeout à 1800 (30 minutes)"
    echo "   b) Retirer complètement le timeout"
    echo "   c) Utiliser le wrapper intelligent qui gère mieux les timeouts"
    echo
    echo "3. Pour utiliser le wrapper sans timeout :"
    echo "   - Remplacer '/opt/scripts/yt-dlp-wrapper.sh' par"
    echo "   - '/opt/scripts/yt-dlp-wrapper-notimeout.sh' dans le code PHP"
    echo
    echo "4. Pour débugger davantage :"
    echo "   - Activer les logs détaillés dans yt-dlp"
    echo "   - Surveiller /var/log/pi-signage/php-error.log"
    echo "   - Tester avec des vidéos plus courtes d'abord"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_info "=== Fix du problème de timeout YouTube ==="
    
    # Vérifier qu'on est root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Appliquer les fixes
    fix_wrapper
    check_timeout_source
    create_smart_wrapper
    
    # Tester
    echo
    read -p "Voulez-vous tester les wrappers ? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        test_wrappers
    fi
    
    # Afficher les recommandations
    show_recommendations
    
    echo
    log_info "=== Fix appliqué ==="
    log_info "Prochaine étape : Modifier le code PHP pour utiliser un des nouveaux wrappers"
}

main "$@"