#!/bin/bash

# Script de vérification pré-installation
# Exécuter avant main_orchestrator.sh pour s'assurer que le système est prêt

echo "=== Vérification pré-installation Pi Signage ==="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

errors=0
warnings=0

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗ Ce script doit être exécuté en tant que root${NC}"
    ((errors++))
else
    echo -e "${GREEN}✓ Exécution en tant que root${NC}"
fi

# Vérifier la connexion internet
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Connexion internet OK${NC}"
else
    echo -e "${RED}✗ Pas de connexion internet${NC}"
    ((errors++))
fi

# Vérifier l'espace disque
free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $free_space -lt 5 ]]; then
    echo -e "${RED}✗ Espace disque insuffisant (${free_space}GB < 5GB requis)${NC}"
    ((errors++))
else
    echo -e "${GREEN}✓ Espace disque suffisant (${free_space}GB)${NC}"
fi

# Vérifier dpkg
if dpkg --audit 2>&1 | grep -q "packages"; then
    echo -e "${YELLOW}⚠ Des paquets nécessitent une configuration${NC}"
    echo "  Exécutez: sudo dpkg --configure -a"
    ((warnings++))
else
    echo -e "${GREEN}✓ dpkg en bon état${NC}"
fi

# Vérifier les verrous dpkg
if lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo -e "${RED}✗ dpkg est verrouillé (processus en cours)${NC}"
    ((errors++))
else
    echo -e "${GREEN}✓ Pas de verrou dpkg${NC}"
fi

# Vérifier les dépendances cassées
if ! apt-get check >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Dépendances cassées détectées${NC}"
    echo "  Exécutez: sudo apt-get install -f"
    ((warnings++))
else
    echo -e "${GREEN}✓ Pas de dépendances cassées${NC}"
fi

# Vérifier les sources apt
if [[ -f /etc/apt/sources.list ]]; then
    echo -e "${GREEN}✓ Sources apt présentes${NC}"
else
    echo -e "${RED}✗ /etc/apt/sources.list manquant${NC}"
    ((errors++))
fi

# Vérifier l'OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == "raspbian" ]] || [[ "$ID" == "debian" ]]; then
        echo -e "${GREEN}✓ OS compatible: $PRETTY_NAME${NC}"
    else
        echo -e "${YELLOW}⚠ OS non standard: $PRETTY_NAME${NC}"
        ((warnings++))
    fi
else
    echo -e "${RED}✗ Impossible de détecter l'OS${NC}"
    ((errors++))
fi

# Résumé
echo ""
echo "=== Résumé ==="
if [[ $errors -eq 0 ]]; then
    if [[ $warnings -eq 0 ]]; then
        echo -e "${GREEN}✓ Système prêt pour l'installation !${NC}"
    else
        echo -e "${YELLOW}⚠ Système prêt avec $warnings avertissement(s)${NC}"
        echo "  L'installation peut continuer mais vérifiez les avertissements"
    fi
    echo ""
    echo "Lancez: sudo ./main_orchestrator.sh"
else
    echo -e "${RED}✗ $errors erreur(s) bloquante(s) détectée(s)${NC}"
    echo "  Corrigez les erreurs avant de lancer l'installation"
fi

exit $errors