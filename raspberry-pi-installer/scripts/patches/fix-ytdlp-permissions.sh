#!/bin/bash

# Script de correction des permissions pour yt-dlp
# Ce script résout les problèmes d'exécution de yt-dlp par www-data

set -euo pipefail

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

echo -e "${GREEN}=== Correction des permissions yt-dlp ===${NC}"

# Vérifier qu'on est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté avec sudo${NC}"
   exit 1
fi

# 1. Créer un wrapper pour yt-dlp
echo -e "${YELLOW}Création du wrapper yt-dlp...${NC}"
cat > /opt/scripts/yt-dlp-wrapper.sh << 'EOF'
#!/bin/bash
# Wrapper pour yt-dlp avec environnement correct

# Définir l'environnement
export HOME=/var/www
export PATH=/usr/local/bin:/usr/bin:/bin
export PYTHONIOENCODING=utf-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Créer le répertoire cache si nécessaire
mkdir -p /var/www/.cache/yt-dlp
chmod 755 /var/www/.cache
chown -R www-data:www-data /var/www/.cache

# Exécuter yt-dlp avec les arguments
exec /usr/local/bin/yt-dlp "$@"
EOF

chmod 755 /opt/scripts/yt-dlp-wrapper.sh
echo -e "${GREEN}✓ Wrapper créé${NC}"

# 2. Créer le répertoire home pour www-data si nécessaire
if [ ! -d "/var/www/.cache" ]; then
    echo -e "${YELLOW}Création du répertoire cache...${NC}"
    mkdir -p /var/www/.cache/yt-dlp
    chown -R www-data:www-data /var/www/.cache
    chmod -R 755 /var/www/.cache
    echo -e "${GREEN}✓ Répertoire cache créé${NC}"
fi

# 3. Ajouter les permissions sudo pour le wrapper
echo -e "${YELLOW}Ajout des permissions sudo...${NC}"
if ! grep -q "yt-dlp-wrapper.sh" /etc/sudoers.d/pi-signage-web 2>/dev/null; then
    echo "www-data ALL=(ALL) NOPASSWD: /opt/scripts/yt-dlp-wrapper.sh" >> /etc/sudoers.d/pi-signage-web
    chmod 440 /etc/sudoers.d/pi-signage-web
    echo -e "${GREEN}✓ Permissions sudo ajoutées${NC}"
else
    echo -e "${GREEN}✓ Permissions sudo déjà présentes${NC}"
fi

# 4. Créer un lien symbolique si nécessaire
if [ ! -L "/usr/local/bin/yt-dlp-web" ]; then
    ln -s /opt/scripts/yt-dlp-wrapper.sh /usr/local/bin/yt-dlp-web
    echo -e "${GREEN}✓ Lien symbolique créé${NC}"
fi

# 5. Tester l'exécution
echo -e "${YELLOW}Test d'exécution...${NC}"
if sudo -u www-data /opt/scripts/yt-dlp-wrapper.sh --version >/dev/null 2>&1; then
    echo -e "${GREEN}✓ yt-dlp fonctionne correctement avec www-data${NC}"
else
    echo -e "${RED}✗ Problème d'exécution avec www-data${NC}"
    echo "Tentative avec sudo..."
    if sudo -u www-data sudo /opt/scripts/yt-dlp-wrapper.sh --version; then
        echo -e "${GREEN}✓ Fonctionne avec sudo${NC}"
    else
        echo -e "${RED}✗ Ne fonctionne pas même avec sudo${NC}"
    fi
fi

echo -e "${GREEN}=== Correction terminée ===${NC}"
echo ""
echo "Le wrapper yt-dlp a été configuré. Les scripts PHP doivent maintenant utiliser:"
echo "  - Sans sudo: /opt/scripts/yt-dlp-wrapper.sh"
echo "  - Avec sudo: sudo /opt/scripts/yt-dlp-wrapper.sh"