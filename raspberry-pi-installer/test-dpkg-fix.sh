#!/bin/bash

# Script de test pour débugger dpkg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

# Charger les fonctions
source "$SCRIPT_DIR/00-security-utils.sh"

echo "=== Test de réparation dpkg ==="
echo ""

echo "1. État initial de dpkg:"
if check_dpkg_health; then
    echo "   ✓ dpkg est sain"
else
    echo "   ✗ dpkg a des problèmes"
fi

echo ""
echo "2. Tentative de réparation:"
repair_dpkg

echo ""
echo "3. État après réparation:"
if check_dpkg_health; then
    echo "   ✓ dpkg est maintenant sain"
else
    echo "   ✗ dpkg a toujours des problèmes"
fi

echo ""
echo "4. Test d'une commande apt avec safe_execute:"
safe_execute "apt-get update" 2 5

echo ""
echo "=== Fin du test ==="