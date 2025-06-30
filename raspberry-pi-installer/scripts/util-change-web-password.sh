#!/usr/bin/env bash

# =============================================================================
# Script utilitaire pour changer le mot de passe de l'interface web
# =============================================================================

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Configuration
readonly CONFIG_FILE="/var/www/pi-signage/includes/config.php"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les fonctions de sécurité
if [[ -f "$SCRIPT_DIR/00-security-utils.sh" ]]; then
    source "$SCRIPT_DIR/00-security-utils.sh"
else
    # Fonction hash_password locale si security-utils n'est pas disponible
    hash_password() {
        local password="$1"
        local salt="${2:-$(openssl rand -hex 16)}"
        local hash
        hash=$(echo -n "${salt}${password}" | sha512sum | cut -d' ' -f1)
        echo "${salt}:${hash}"
    }
fi

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Vérifier que le fichier de config existe
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Fichier de configuration non trouvé: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}=== Changement du mot de passe de l'interface web ===${NC}"
echo

# Obtenir le nom d'utilisateur actuel
current_user=$(grep "ADMIN_USERNAME" "$CONFIG_FILE" | cut -d"'" -f4)
echo -e "Utilisateur actuel: ${YELLOW}$current_user${NC}"
echo

# Demander le nouveau mot de passe
while true; do
    read -rsp "Nouveau mot de passe: " new_password
    echo
    
    if [[ ${#new_password} -lt 8 ]]; then
        echo -e "${RED}Le mot de passe doit contenir au moins 8 caractères${NC}"
        continue
    fi
    
    read -rsp "Confirmer le mot de passe: " confirm_password
    echo
    
    if [[ "$new_password" != "$confirm_password" ]]; then
        echo -e "${RED}Les mots de passe ne correspondent pas${NC}"
        continue
    fi
    
    break
done

# Générer le nouveau hash
echo -e "\n${YELLOW}Génération du nouveau hash...${NC}"
new_hash=$(hash_password "$new_password")

# Créer une sauvegarde
echo -e "${YELLOW}Création d'une sauvegarde...${NC}"
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

# Mettre à jour le fichier
echo -e "${YELLOW}Mise à jour de la configuration...${NC}"
if sed -i "s|define('ADMIN_PASSWORD_HASH', '.*');|define('ADMIN_PASSWORD_HASH', '$new_hash');|" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ Mot de passe mis à jour avec succès${NC}"
    
    # Afficher le hash pour vérification
    echo -e "\nNouveau hash: ${YELLOW}$new_hash${NC}"
    
    # Redémarrer PHP-FPM pour s'assurer que les changements sont pris en compte
    if systemctl restart php8.2-fpm 2>/dev/null; then
        echo -e "${GREEN}✓ Service PHP-FPM redémarré${NC}"
    fi
    
    echo -e "\n${GREEN}Vous pouvez maintenant vous connecter avec le nouveau mot de passe${NC}"
else
    echo -e "${RED}✗ Erreur lors de la mise à jour du mot de passe${NC}"
    exit 1
fi