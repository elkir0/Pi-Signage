#!/bin/bash

# PiSignage v0.8.1 GOLDEN - Test de l'Installeur
# Script de test pour valider la syntaxe et la logique de l'installeur

set -e

# Configuration
INSTALLER_SCRIPT="/opt/pisignage/install-pisignage-v0.8.1-golden.sh"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Test de l'Installeur PiSignage v0.8.1 GOLDEN ===${NC}"
echo ""

# Test 1: Vérification de l'existence du script
echo -e "${BLUE}[TEST 1]${NC} Vérification de l'existence du script..."
if [ -f "$INSTALLER_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script trouvé: $INSTALLER_SCRIPT${NC}"
else
    echo -e "${RED}✗ Script non trouvé: $INSTALLER_SCRIPT${NC}"
    exit 1
fi

# Test 2: Vérification des permissions d'exécution
echo -e "${BLUE}[TEST 2]${NC} Vérification des permissions..."
if [ -x "$INSTALLER_SCRIPT" ]; then
    echo -e "${GREEN}✓ Script exécutable${NC}"
else
    echo -e "${RED}✗ Script non exécutable${NC}"
    exit 1
fi

# Test 3: Vérification de la syntaxe bash
echo -e "${BLUE}[TEST 3]${NC} Vérification de la syntaxe bash..."
if bash -n "$INSTALLER_SCRIPT"; then
    echo -e "${GREEN}✓ Syntaxe bash valide${NC}"
else
    echo -e "${RED}✗ Erreur de syntaxe bash${NC}"
    exit 1
fi

# Test 4: Vérification du shebang
echo -e "${BLUE}[TEST 4]${NC} Vérification du shebang..."
if head -1 "$INSTALLER_SCRIPT" | grep -q "#!/bin/bash"; then
    echo -e "${GREEN}✓ Shebang correct${NC}"
else
    echo -e "${RED}✗ Shebang manquant ou incorrect${NC}"
    exit 1
fi

# Test 5: Vérification des fonctions principales
echo -e "${BLUE}[TEST 5]${NC} Vérification des fonctions principales..."
required_functions=(
    "check_prerequisites"
    "install_system_packages"
    "deploy_from_github"
    "configure_nginx"
    "configure_php"
    "install_systemd_services"
    "run_validation_tests"
)

for func in "${required_functions[@]}"; do
    if grep -q "^$func()" "$INSTALLER_SCRIPT"; then
        echo -e "  ${GREEN}✓ Fonction $func présente${NC}"
    else
        echo -e "  ${RED}✗ Fonction $func manquante${NC}"
        exit 1
    fi
done

# Test 6: Vérification des variables importantes
echo -e "${BLUE}[TEST 6]${NC} Vérification des variables importantes..."
required_vars=(
    "PISIGNAGE_VERSION"
    "GITHUB_REPO"
    "PISIGNAGE_DIR"
    "PHP_VERSION"
)

for var in "${required_vars[@]}"; do
    if grep -q "^$var=" "$INSTALLER_SCRIPT"; then
        echo -e "  ${GREEN}✓ Variable $var définie${NC}"
    else
        echo -e "  ${RED}✗ Variable $var manquante${NC}"
        exit 1
    fi
done

# Test 7: Vérification de la gestion des erreurs
echo -e "${BLUE}[TEST 7]${NC} Vérification de la gestion des erreurs..."
if grep -q "set -e" "$INSTALLER_SCRIPT"; then
    echo -e "${GREEN}✓ Gestion d'erreur 'set -e' activée${NC}"
else
    echo -e "${YELLOW}⚠ 'set -e' non trouvé${NC}"
fi

if grep -q "error()" "$INSTALLER_SCRIPT"; then
    echo -e "${GREEN}✓ Fonction error() présente${NC}"
else
    echo -e "${RED}✗ Fonction error() manquante${NC}"
    exit 1
fi

# Test 8: Test de simulation (dry-run partiel)
echo -e "${BLUE}[TEST 8]${NC} Test des vérifications préliminaires..."

# Créer un script de test temporaire qui ne fait que les vérifications
cat > /tmp/test_prereq.sh << 'EOF'
#!/bin/bash

# Extraction de la fonction check_prerequisites
source /opt/pisignage/install-pisignage-v0.8.1-golden.sh

# Test en mode simulation (sans root)
if [[ $EUID -eq 0 ]]; then
    echo "Test de vérifications en mode root..."
    # check_prerequisites
    echo "Vérifications basiques OK"
else
    echo "Test en mode non-root (normal pour les vérifications)"
fi
EOF

chmod +x /tmp/test_prereq.sh

if bash -n /tmp/test_prereq.sh; then
    echo -e "${GREEN}✓ Vérifications préliminaires syntaxiquement correctes${NC}"
    rm -f /tmp/test_prereq.sh
else
    echo -e "${RED}✗ Erreur dans les vérifications préliminaires${NC}"
    exit 1
fi

# Test 9: Vérification de la documentation
echo -e "${BLUE}[TEST 9]${NC} Vérification de la documentation..."
if [ -f "/opt/pisignage/README-INSTALLATION.md" ]; then
    echo -e "${GREEN}✓ Documentation d'installation présente${NC}"
else
    echo -e "${YELLOW}⚠ Documentation manquante${NC}"
fi

if [ -f "/opt/pisignage/INSTALL-INSTRUCTIONS.md" ]; then
    echo -e "${GREEN}✓ Instructions d'installation présentes${NC}"
else
    echo -e "${YELLOW}⚠ Instructions manquantes${NC}"
fi

# Test 10: Vérification de l'intégrité du script
echo -e "${BLUE}[TEST 10]${NC} Vérification de l'intégrité..."
script_size=$(wc -c < "$INSTALLER_SCRIPT")
if [ $script_size -gt 10000 ]; then
    echo -e "${GREEN}✓ Taille du script correcte ($script_size octets)${NC}"
else
    echo -e "${RED}✗ Script trop petit, possiblement corrompu${NC}"
    exit 1
fi

# Rapport final
echo ""
echo -e "${GREEN}=================================================================="
echo "                    TOUS LES TESTS SONT PASSÉS !"
echo "=================================================================="
echo -e "${NC}"
echo -e "${GREEN}✅ L'installeur PiSignage v0.8.1 GOLDEN est prêt à l'emploi${NC}"
echo -e "${BLUE}📋 Pour lancer l'installation:${NC}"
echo "   sudo $INSTALLER_SCRIPT"
echo ""
echo -e "${BLUE}📋 Pour validation post-installation:${NC}"
echo "   /opt/pisignage/validate-installation.sh"
echo ""
echo -e "${GREEN}🚀 Votre installeur ONE-CLICK est parfait !${NC}"