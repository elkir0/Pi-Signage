#!/bin/bash
# deploy.sh - Script de déploiement automatique PiSignage
# Usage: ./deploy.sh <source_file> <dest_path>

PI_IP="192.168.1.103"
PI_USER="pi"
PI_PASS="raspberry"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$#" -ne 2 ]; then
    echo -e "${RED}❌ Usage: ./deploy.sh <source_file> <dest_path>${NC}"
    echo "Example: ./deploy.sh web/api/stats.php /opt/pisignage/web/api"
    exit 1
fi

SOURCE=$1
DEST=$2
FILENAME=$(basename $SOURCE)

# Check if source file exists
if [ ! -f "$SOURCE" ]; then
    echo -e "${RED}❌ Error: Source file $SOURCE does not exist${NC}"
    exit 1
fi

echo -e "${YELLOW}📤 Déploiement de $FILENAME vers Pi ($PI_IP)...${NC}"

# Copy to /tmp first
echo "1. Copie vers /tmp..."
sshpass -p $PI_PASS scp $SOURCE $PI_USER@$PI_IP:/tmp/

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erreur lors de la copie${NC}"
    exit 1
fi

# Move with proper permissions
echo "2. Déplacement avec permissions www-data..."
sshpass -p $PI_PASS ssh $PI_USER@$PI_IP "sudo mv /tmp/$FILENAME $DEST/$FILENAME && sudo chown www-data:www-data $DEST/$FILENAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erreur lors du déplacement${NC}"
    exit 1
fi

# Test if it's an API file
if [[ $DEST == */api* ]] && [[ $FILENAME == *.php ]]; then
    echo "3. Test de l'API..."
    API_NAME="${FILENAME%.php}"
    RESPONSE=$(curl -s http://$PI_IP/api/$FILENAME)
    SUCCESS=$(echo $RESPONSE | jq -r '.success' 2>/dev/null)

    if [ "$SUCCESS" == "true" ]; then
        echo -e "${GREEN}✅ API $API_NAME fonctionnelle${NC}"
    else
        echo -e "${YELLOW}⚠️  Vérifier manuellement: http://$PI_IP/api/$FILENAME${NC}"
    fi
fi

echo -e "${GREEN}✅ Déploiement terminé!${NC}"
echo ""
echo "📋 Prochaines étapes:"
echo "1. Tester sur http://$PI_IP"
echo "2. git add $SOURCE"
echo "3. git commit -m '🔧 Deploy: $FILENAME'"
echo "4. git push origin main"