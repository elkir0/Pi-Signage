#!/bin/bash

echo "======================================"
echo "   CONFIGURATION WIFI FULLPAGEOS"
echo "======================================"
echo ""

# Demander les informations
read -p "📡 Nom du WiFi (SSID) : " WIFI_SSID
read -sp "🔐 Mot de passe WiFi : " WIFI_PASS
echo ""
echo ""

# Générer un UUID unique
UUID=$(uuidgen 2>/dev/null || echo "e56bf8e2-3d4f-4b8e-9f3a-8c5d60b81412")

# Créer le fichier de configuration
cat > wifi.nmconnection << EOF
[connection]
id=WiFi
uuid=$UUID
type=wifi
autoconnect=true
interface-name=wlan0

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$WIFI_PASS

[ipv4]
method=auto

[ipv6]
method=auto

[proxy]
EOF

echo "✅ Fichier wifi.nmconnection créé !"
echo ""
echo "📋 Instructions :"
echo ""
echo "1. Copiez ce fichier sur la carte SD après flash :"
echo "   - Windows : Coller dans le lecteur BOOT"
echo "   - Linux/Mac : cp wifi.nmconnection /media/boot/"
echo ""
echo "2. OU si la carte SD est montée :"
read -p "   La carte SD est-elle montée ? (chemin ou n) : " SD_PATH

if [ "$SD_PATH" != "n" ] && [ -d "$SD_PATH" ]; then
    # Chercher le bon emplacement
    if [ -d "$SD_PATH/boot" ]; then
        TARGET="$SD_PATH/boot/wifi.nmconnection"
    elif [ -d "$SD_PATH/firmware" ]; then
        TARGET="$SD_PATH/firmware/wifi.nmconnection"
    else
        TARGET="$SD_PATH/wifi.nmconnection"
    fi
    
    echo ""
    echo "🔄 Copie vers $TARGET..."
    sudo cp wifi.nmconnection "$TARGET"
    sudo chmod 600 "$TARGET"
    echo "✅ Fichier copié !"
    echo ""
    echo "🎉 Configuration terminée !"
    echo "   Vous pouvez maintenant insérer la carte SD dans le Pi"
else
    echo ""
    echo "📁 Le fichier wifi.nmconnection est dans le dossier actuel"
    echo "   Copiez-le manuellement sur la carte SD dans /boot/"
fi

echo ""
echo "🔍 Après démarrage du Pi, il sera accessible via :"
echo "   - Hostname : ssh pi@pisignage.local"
echo "   - Ou cherchez son IP sur votre routeur"
echo ""
echo "💡 Mot de passe SSH : palmer00"