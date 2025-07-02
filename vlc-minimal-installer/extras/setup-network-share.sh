#!/bin/bash

# =============================================================================
# Configuration partage réseau SMB/CIFS (optionnel)
# Version: 1.0.0
# Description: Monte automatiquement un partage réseau pour les vidéos
# =============================================================================

set -euo pipefail

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Configuration partage réseau ===${NC}"
echo ""

# Installer les dépendances
if ! dpkg -l | grep -q cifs-utils; then
    echo -e "${YELLOW}Installation de cifs-utils...${NC}"
    sudo apt-get update
    sudo apt-get install -y cifs-utils
fi

# Collecter les informations
echo -e "${YELLOW}Configuration du partage réseau :${NC}"
read -p "Adresse IP du serveur : " server_ip
read -p "Nom du partage : " share_name
read -p "Nom d'utilisateur : " username
read -s -p "Mot de passe : " password
echo ""

# Créer le point de montage
MOUNT_POINT="$HOME/Videos-Network"
mkdir -p "$MOUNT_POINT"

# Créer le fichier de credentials
CRED_FILE="$HOME/.smbcredentials"
cat > "$CRED_FILE" << EOF
username=$username
password=$password
domain=WORKGROUP
EOF

chmod 600 "$CRED_FILE"

# Tester la connexion
echo -e "${YELLOW}Test de connexion...${NC}"
if sudo mount -t cifs "//$server_ip/$share_name" "$MOUNT_POINT" -o credentials="$CRED_FILE",uid=$(id -u),gid=$(id -g),iocharset=utf8; then
    echo -e "${GREEN}✓ Connexion réussie !${NC}"
    sudo umount "$MOUNT_POINT"
else
    echo -e "${RED}✗ Échec de connexion${NC}"
    exit 1
fi

# Ajouter au fstab pour montage automatique
echo -e "${YELLOW}Configuration du montage automatique...${NC}"
FSTAB_LINE="//$server_ip/$share_name $MOUNT_POINT cifs credentials=$CRED_FILE,uid=$(id -u),gid=$(id -g),iocharset=utf8,file_mode=0755,dir_mode=0755,_netdev 0 0"

if ! grep -q "$server_ip/$share_name" /etc/fstab; then
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
fi

# Monter le partage
sudo mount "$MOUNT_POINT"

# Créer un lien symbolique dans le dossier Videos
ln -sf "$MOUNT_POINT" "$HOME/Videos/Network"

echo ""
echo -e "${GREEN}✓ Configuration terminée !${NC}"
echo ""
echo "Le partage réseau est monté dans : $MOUNT_POINT"
echo "Un lien est créé dans : $HOME/Videos/Network"
echo ""
echo -e "${YELLOW}Pour que VLC lise aussi ces vidéos, modifiez le fichier autostart :${NC}"
echo "Remplacez '$HOME/Videos' par '$HOME/Videos $MOUNT_POINT'"