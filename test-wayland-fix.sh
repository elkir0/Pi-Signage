#!/bin/bash
################################################################################
#                    TEST SCRIPT - WAYLAND FIX VALIDATION
#                       Script de test pour fix-graphical-wayland.sh
################################################################################

set -e

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               TEST DE VALIDATION DU SCRIPT WAYLAND          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Vérification syntaxe
echo -e "${BLUE}[TEST 1]${NC} Vérification de la syntaxe du script..."
if bash -n /opt/pisignage/fix-graphical-wayland.sh; then
    echo -e "${GREEN}✓${NC} Syntaxe correcte"
else
    echo -e "${RED}✗${NC} Erreur de syntaxe détectée"
    exit 1
fi

# Test 2: Vérification permissions
echo -e "${BLUE}[TEST 2]${NC} Vérification des permissions..."
if [ -x /opt/pisignage/fix-graphical-wayland.sh ]; then
    echo -e "${GREEN}✓${NC} Script exécutable"
else
    echo -e "${RED}✗${NC} Script non exécutable"
    exit 1
fi

# Test 3: Vérification des dépendances système
echo -e "${BLUE}[TEST 3]${NC} Vérification des dépendances système..."

deps_ok=true

if ! command -v apt-get >/dev/null; then
    echo -e "${RED}✗${NC} apt-get non disponible"
    deps_ok=false
fi

if ! command -v systemctl >/dev/null; then
    echo -e "${RED}✗${NC} systemctl non disponible"
    deps_ok=false
fi

if [ ! -f /etc/os-release ]; then
    echo -e "${RED}✗${NC} /etc/os-release non trouvé"
    deps_ok=false
fi

if $deps_ok; then
    echo -e "${GREEN}✓${NC} Dépendances système OK"
else
    echo -e "${RED}✗${NC} Certaines dépendances manquantes"
fi

# Test 4: Détection de l'OS
echo -e "${BLUE}[TEST 4]${NC} Détection de l'OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}✓${NC} OS détecté: $ID $VERSION_ID ($VERSION_CODENAME)"

    if [[ "$VERSION_CODENAME" == "bookworm" ]]; then
        echo -e "${GREEN}✓${NC} Raspberry Pi OS Bookworm détecté (optimal)"
    else
        echo -e "${YELLOW}⚠${NC} OS non-Bookworm: $VERSION_CODENAME (peut fonctionner)"
    fi
fi

# Test 5: État actuel du système
echo -e "${BLUE}[TEST 5]${NC} État actuel du système..."
current_target=$(systemctl get-default)
echo "  Target actuel: $current_target"

if [ "$current_target" = "graphical.target" ]; then
    echo -e "${GREEN}✓${NC} Système déjà en mode graphique"
else
    echo -e "${YELLOW}⚠${NC} Système en mode console - correction nécessaire"
fi

# Test 6: Vérification des packages Wayland existants
echo -e "${BLUE}[TEST 6]${NC} Packages Wayland existants..."
wayland_count=$(dpkg -l | grep -i wayland | wc -l)
echo "  Packages Wayland installés: $wayland_count"

if [ $wayland_count -gt 5 ]; then
    echo -e "${GREEN}✓${NC} Base Wayland déjà présente"
else
    echo -e "${YELLOW}⚠${NC} Peu de packages Wayland - installation complète nécessaire"
fi

# Test 7: Vérification de l'utilisateur pi
echo -e "${BLUE}[TEST 7]${NC} Utilisateur pi..."
if id -u pi >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Utilisateur pi existe"
    groups_pi=$(groups pi | cut -d: -f2)
    echo "  Groupes actuels: $groups_pi"
else
    echo -e "${YELLOW}⚠${NC} Utilisateur pi n'existe pas - sera créé"
fi

# Test 8: Espace disque
echo -e "${BLUE}[TEST 8]${NC} Espace disque disponible..."
available_gb=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
echo "  Espace disponible: ${available_gb}GB"

if [ $available_gb -lt 2 ]; then
    echo -e "${RED}✗${NC} Espace disque insuffisant (< 2GB)"
    exit 1
elif [ $available_gb -lt 5 ]; then
    echo -e "${YELLOW}⚠${NC} Espace disque faible (< 5GB) - surveillance recommandée"
else
    echo -e "${GREEN}✓${NC} Espace disque suffisant"
fi

# Test 9: Connexion réseau
echo -e "${BLUE}[TEST 9]${NC} Connexion réseau..."
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Connexion Internet OK"
else
    echo -e "${RED}✗${NC} Pas de connexion Internet"
    exit 1
fi

# Test 10: Permissions root
echo -e "${BLUE}[TEST 10]${NC} Test des permissions (sera vérifié au lancement)..."
if [ "$EUID" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Script lancé en tant que root"
else
    echo -e "${YELLOW}⚠${NC} Script non lancé en tant que root - utiliser sudo"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    RÉSUMÉ DU TEST                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✓${NC} Script validé et prêt à l'exécution"
echo ""
echo "🚀 COMMANDE D'EXÉCUTION:"
echo "════════════════════════════════════════════════════════════════"
echo "  sudo /opt/pisignage/fix-graphical-wayland.sh"
echo ""
echo "📋 CE QUE LE SCRIPT VA FAIRE:"
echo "════════════════════════════════════════════════════════════════"
echo "  1. ✅ Installer tous les packages Wayland (labwc, seatd, etc.)"
echo "  2. ✅ Configurer le système en graphical.target"
echo "  3. ✅ Créer/configurer l'autologin utilisateur pi"
echo "  4. ✅ Configurer labwc comme compositeur Wayland"
echo "  5. ✅ Configurer les variables d'environnement Wayland"
echo "  6. ✅ Télécharger et configurer VLC avec Big Buck Bunny"
echo "  7. ✅ Configurer l'accès hardware (DRM/GBM) via seatd"
echo "  8. ✅ Créer tous les services nécessaires"
echo ""
echo "⚠️  APRÈS EXÉCUTION:"
echo "════════════════════════════════════════════════════════════════"
echo "  • Le système DOIT être redémarré (reboot obligatoire)"
echo "  • L'utilisateur 'pi' se connectera automatiquement"
echo "  • VLC démarrera automatiquement avec la vidéo de test"
echo "  • L'environnement sera en Wayland avec labwc"
echo ""
echo "✅ PRÊT POUR L'INSTALLATION !"
echo ""