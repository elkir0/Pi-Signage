#!/bin/bash

# Script de test d'upload de fichiers volumineux
# Usage: bash test-upload.sh <IP_RASPBERRY>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

if [ -z "$1" ]; then
    echo "Usage: bash test-upload.sh <IP_RASPBERRY>"
    exit 1
fi

RASPI_IP="$1"
API_URL="http://${RASPI_IP}/api/upload.php"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test d'upload PiSignage v0.8.0                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo

# Créer des fichiers de test de différentes tailles
log_info "Création des fichiers de test..."

TEST_DIR="/tmp/pisignage-test-$(date +%s)"
mkdir -p $TEST_DIR

# Fichier de 1MB
dd if=/dev/urandom of=$TEST_DIR/test_1MB.bin bs=1M count=1 2>/dev/null
log_info "Fichier de 1MB créé"

# Fichier de 10MB
dd if=/dev/urandom of=$TEST_DIR/test_10MB.bin bs=1M count=10 2>/dev/null
log_info "Fichier de 10MB créé"

# Fichier de 50MB
dd if=/dev/urandom of=$TEST_DIR/test_50MB.bin bs=1M count=50 2>/dev/null
log_info "Fichier de 50MB créé"

# Fichier de 100MB (optionnel, peut être lent)
if [ "$2" == "--full" ]; then
    dd if=/dev/urandom of=$TEST_DIR/test_100MB.bin bs=1M count=100 2>/dev/null
    log_info "Fichier de 100MB créé"
fi

echo
echo "Tests d'upload en cours..."
echo

# Fonction de test d'upload
test_upload() {
    local file=$1
    local size=$(du -h $file | cut -f1)
    local filename=$(basename $file)

    echo -n "Upload de $filename ($size)... "

    local start_time=$(date +%s)

    # Utiliser curl pour uploader avec timeout augmenté
    if curl -X POST \
        -F "files[]=@$file" \
        --connect-timeout 30 \
        --max-time 300 \
        -w "\n%{http_code}" \
        -o /tmp/upload_response.json \
        -s \
        $API_URL | grep -q "200\|413"; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        # Vérifier la réponse
        if grep -q "success.*true" /tmp/upload_response.json 2>/dev/null; then
            log_info "OK (${duration}s)"
        elif grep -q "413" /tmp/upload_response.json 2>/dev/null; then
            log_error "Fichier trop volumineux (erreur 413)"
        else
            log_warn "Réponse inattendue"
            cat /tmp/upload_response.json 2>/dev/null || true
        fi
    else
        log_error "ERREUR"
        cat /tmp/upload_response.json 2>/dev/null || true
    fi
}

# Tester chaque fichier
for file in $TEST_DIR/*.bin; do
    test_upload $file
    sleep 2  # Pause entre les uploads
done

# Nettoyer
rm -rf $TEST_DIR
rm -f /tmp/upload_response.json

echo
echo -e "${GREEN}Tests terminés!${NC}"
echo
echo "Pour vérifier les fichiers uploadés:"
echo "  • Ouvrez http://${RASPI_IP}/ dans votre navigateur"
echo "  • Allez dans 'Gestion des médias'"
echo "  • Les fichiers de test devraient apparaître dans la liste"
echo
echo "Pour supprimer les fichiers de test via SSH:"
echo "  ssh pi@${RASPI_IP} 'rm -f /opt/pisignage/media/test_*.bin'"
echo