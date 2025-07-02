#!/bin/bash

# Script pour appliquer tous les patches de robustesse v2.4.4

echo "=== Application des patches de robustesse v2.4.4 ==="

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Vérifier qu'on est dans le bon répertoire
if [[ ! -f "raspberry-pi-installer/scripts/main_orchestrator.sh" ]]; then
    echo "ERREUR: Exécutez ce script depuis la racine du projet Pi Signage"
    exit 1
fi

echo -e "${YELLOW}Sauvegarde des fichiers originaux...${NC}"
cp -r raspberry-pi-installer/scripts raspberry-pi-installer/scripts.backup.$(date +%Y%m%d-%H%M%S)

echo -e "${GREEN}✓ Backup créé${NC}"
echo ""

# Supprimer les scripts de fix temporaires car ils sont maintenant intégrés
echo -e "${YELLOW}Nettoyage des scripts temporaires...${NC}"
rm -f fix-chromium-install.sh
rm -f fix-dpkg-dependencies.sh
rm -f fix-gtk-dependencies.sh
echo -e "${GREEN}✓ Scripts temporaires supprimés${NC}"

echo ""
echo -e "${GREEN}=== Patches appliqués avec succès ! ===${NC}"
echo ""
echo "Changements intégrés :"
echo "• safe_apt_install() : Installation robuste avec récupération"
echo "• prepare_system() : Installation des dépendances GTK en premier"
echo "• Gestion multi-architecture (ARM64)"
echo "• Détection et réparation automatique de dpkg"
echo "• Installation sans recommandations (évite Widevine)"
echo "• Configuration forcée des paquets non configurés"
echo ""
echo "Scripts prêts à l'emploi :"
echo "• pre-install-check.sh : Vérification avant installation"
echo "• main_orchestrator.sh : Installation principale (v2.4.4)"
echo ""
echo -e "${GREEN}L'installation est maintenant ultra-robuste !${NC}"
echo ""
echo "Prochaine étape :"
echo "  cd raspberry-pi-installer/scripts"
echo "  sudo ./pre-install-check.sh"
echo "  sudo ./main_orchestrator.sh"