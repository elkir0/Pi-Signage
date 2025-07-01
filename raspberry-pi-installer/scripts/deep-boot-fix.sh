#!/bin/bash

# Script de réparation profonde pour blocage au boot
echo "=== Réparation profonde du boot Raspberry Pi ==="
echo ""

read -p "Chemin vers la partition root du Pi (ex: /media/user/rootfs): " ROOT_PATH
read -p "Chemin vers la partition boot du Pi (ex: /media/user/boot): " BOOT_PATH

if [[ ! -d "$ROOT_PATH/etc" ]] || [[ ! -f "$BOOT_PATH/cmdline.txt" ]]; then
    echo "ERREUR: Chemins invalides"
    exit 1
fi

echo ""
echo "1. Modification de cmdline.txt pour forcer le boot en mode rescue..."

# Backup
cp "$BOOT_PATH/cmdline.txt" "$BOOT_PATH/cmdline.txt.backup-$(date +%s)"

# Lire la ligne actuelle
CMDLINE=$(cat "$BOOT_PATH/cmdline.txt")

# Créer plusieurs options de boot
cat > "$BOOT_PATH/cmdline.txt" << EOF
$CMDLINE systemd.unit=rescue.target
EOF

cat > "$BOOT_PATH/cmdline-emergency.txt" << EOF
$CMDLINE systemd.unit=emergency.target init=/bin/bash
EOF

cat > "$BOOT_PATH/cmdline-safe.txt" << EOF
$CMDLINE systemd.unit=multi-user.target nomodeset
EOF

echo "2. Désactivation des services problématiques au niveau systemd..."

# Désactiver TOUS les services non essentiels
SERVICES_TO_DISABLE=(
    "lightdm"
    "gdm3"
    "xrdp"
    "vlc-signage"
    "chromium-kiosk"
    "glances"
    "pi-signage-watchdog"
    "plymouth"
    "raspi-config"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    # Chercher dans tous les targets
    find "$ROOT_PATH/etc/systemd/system" -name "${service}*" -type l -delete 2>/dev/null
    find "$ROOT_PATH/lib/systemd/system" -name "${service}*" -type l -delete 2>/dev/null
done

echo "3. Création d'un script de réparation automatique..."

cat > "$ROOT_PATH/root/fix-boot.sh" << 'FIXSCRIPT'
#!/bin/bash

echo "=== Réparation automatique du boot ==="

# Nettoyer les fichiers temporaires qui pourraient bloquer
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /run/systemd/sessions/*

# Reconstruire les caches systemd
systemctl daemon-reexec
systemctl daemon-reload

# Vérifier et réparer le système de fichiers
touch /forcefsck

# Désactiver les services graphiques
systemctl disable lightdm.service 2>/dev/null
systemctl disable gdm3.service 2>/dev/null
systemctl disable display-manager.service 2>/dev/null

# Masquer temporairement les services problématiques
systemctl mask systemd-tmpfiles-setup.service
systemctl mask systemd-tmpfiles-clean.service

# Nettoyer les journaux qui pourraient être corrompus
journalctl --vacuum-size=10M

# Reconfigurer les paquets de base
dpkg --configure -a
apt-get update
apt-get install -f -y

# Régénérer les configurations de base
update-initramfs -u

echo "Réparation terminée. Redémarrage nécessaire."
FIXSCRIPT

chmod +x "$ROOT_PATH/root/fix-boot.sh"

echo "4. Configuration d'un getty de secours..."

# Forcer un getty sur tty1
mkdir -p "$ROOT_PATH/etc/systemd/system/getty.target.wants"
ln -sf /lib/systemd/system/getty@.service "$ROOT_PATH/etc/systemd/system/getty.target.wants/getty@tty1.service"

echo "5. Désactivation de quiet et splash..."
sed -i 's/ quiet//g; s/ splash//g; s/ plymouth.ignore-serial-consoles//g' "$BOOT_PATH/cmdline.txt"

echo ""
echo "=== Instructions ==="
echo ""
echo "Options de boot créées :"
echo "1. cmdline.txt : Boot en mode rescue (par défaut)"
echo "2. cmdline-emergency.txt : Boot d'urgence direct en bash"
echo "3. cmdline-safe.txt : Boot sans mode graphique"
echo ""
echo "Pour utiliser une option différente :"
echo "  cp $BOOT_PATH/cmdline-[option].txt $BOOT_PATH/cmdline.txt"
echo ""
echo "Après le boot en mode rescue :"
echo "1. Login: root (ou pi avec sudo -i)"
echo "2. Exécuter: /root/fix-boot.sh"
echo "3. Redémarrer: reboot"
echo ""
echo "Si toujours bloqué, essayez le boot d'urgence :"
echo "  cp $BOOT_PATH/cmdline-emergency.txt $BOOT_PATH/cmdline.txt"