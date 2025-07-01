#!/usr/bin/env bash

# Script de test pour vérifier la correction dpkg
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Test de la correction dpkg ==="
echo

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/scripts/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/scripts/00-security-utils.sh"
    echo "✓ Module de sécurité chargé"
else
    echo "✗ Module de sécurité non trouvé!"
    exit 1
fi

# Test 1: Vérifier l'état initial de dpkg
echo -e "\nTest 1: État de dpkg"
if check_dpkg_health; then
    echo "✓ dpkg est en bon état"
else
    echo "✗ dpkg nécessite une réparation"
fi

# Test 2: Tester init_dpkg_cleanup
echo -e "\nTest 2: Initialisation dpkg"
init_dpkg_cleanup

# Test 3: Tester safe_execute avec une commande apt
echo -e "\nTest 3: Commande apt simple"
safe_execute "apt-get update" 1 5 60

# Test 4: Tester safe_execute avec une commande composée
echo -e "\nTest 4: Commande apt composée"
safe_execute "apt-get update && apt-get install -y --no-install-recommends curl" 1 5 60

# Test 5: Vérifier l'état final
echo -e "\nTest 5: État final de dpkg"
if check_dpkg_health; then
    echo "✓ dpkg est en bon état après les tests"
else
    echo "✗ dpkg a encore des problèmes"
fi

echo -e "\n=== Tests terminés ==="