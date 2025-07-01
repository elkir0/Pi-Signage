#!/bin/bash

# Script d'urgence pour débloquer le boot du Raspberry Pi
# À exécuter depuis un autre ordinateur avec la carte SD montée

echo "=== Script de réparation d'urgence pour Pi Signage ==="
echo ""
echo "Ce script doit être exécuté avec la carte SD du Raspberry Pi montée"
echo "sur un autre ordinateur Linux ou depuis le mode recovery"
echo ""

# Demander le point de montage
read -p "Chemin vers la partition root du Pi (ex: /media/user/rootfs): " ROOT_PATH

if [[ ! -d "$ROOT_PATH/etc" ]]; then
    echo "ERREUR: $ROOT_PATH ne semble pas être une partition root valide"
    exit 1
fi

echo ""
echo "Désactivation des services Pi Signage pour permettre le boot..."

# Désactiver temporairement les services qui peuvent bloquer
for service in vlc-signage chromium-kiosk lightdm glances; do
    if [[ -f "$ROOT_PATH/etc/systemd/system/$service.service" ]] || 
       [[ -f "$ROOT_PATH/lib/systemd/system/$service.service" ]]; then
        echo "- Désactivation de $service"
        rm -f "$ROOT_PATH/etc/systemd/system/multi-user.target.wants/$service.service"
        rm -f "$ROOT_PATH/etc/systemd/system/graphical.target.wants/$service.service"
    fi
done

# Créer un script de diagnostic au boot
cat > "$ROOT_PATH/root/diagnose-boot.sh" << 'EOF'
#!/bin/bash

# Script de diagnostic post-boot
LOG_FILE="/var/log/pi-signage-boot-diagnose.log"

echo "=== Diagnostic Pi Signage - $(date) ===" > "$LOG_FILE"

# Vérifier les services en échec
echo "Services en échec:" >> "$LOG_FILE"
systemctl --failed >> "$LOG_FILE" 2>&1

# Vérifier les logs de boot
echo -e "\nDerniers logs de boot:" >> "$LOG_FILE"
journalctl -b -p err >> "$LOG_FILE" 2>&1

# Vérifier l'espace disque
echo -e "\nEspace disque:" >> "$LOG_FILE"
df -h >> "$LOG_FILE"

# Vérifier la mémoire
echo -e "\nMémoire:" >> "$LOG_FILE"
free -h >> "$LOG_FILE"

# Vérifier les processus
echo -e "\nProcessus gourmands:" >> "$LOG_FILE"
ps aux --sort=-%cpu | head -20 >> "$LOG_FILE"

echo -e "\nDiagnostic terminé. Résultats dans $LOG_FILE"
EOF

chmod +x "$ROOT_PATH/root/diagnose-boot.sh"

# Ajouter un service oneshot pour le diagnostic
cat > "$ROOT_PATH/etc/systemd/system/pi-signage-diagnose.service" << 'EOF'
[Unit]
Description=Pi Signage Boot Diagnostic
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/root/diagnose-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ln -sf "$ROOT_PATH/etc/systemd/system/pi-signage-diagnose.service" \
       "$ROOT_PATH/etc/systemd/system/multi-user.target.wants/"

# Modifier cmdline.txt pour activer les logs verbose
if [[ -f "$ROOT_PATH/../boot/cmdline.txt" ]]; then
    echo ""
    echo "Activation des logs de boot verbose..."
    cp "$ROOT_PATH/../boot/cmdline.txt" "$ROOT_PATH/../boot/cmdline.txt.backup"
    sed -i 's/quiet//g' "$ROOT_PATH/../boot/cmdline.txt"
    sed -i 's/splash//g' "$ROOT_PATH/../boot/cmdline.txt"
    sed -i 's/plymouth.ignore-serial-consoles//g' "$ROOT_PATH/../boot/cmdline.txt"
fi

echo ""
echo "=== Réparation terminée ==="
echo ""
echo "Actions effectuées:"
echo "1. Services Pi Signage désactivés temporairement"
echo "2. Script de diagnostic créé (/root/diagnose-boot.sh)"
echo "3. Logs de boot verbose activés"
echo ""
echo "Prochaines étapes:"
echo "1. Réinsérer la carte SD dans le Raspberry Pi"
echo "2. Démarrer le Pi (il devrait maintenant booter)"
echo "3. Se connecter et exécuter: sudo /root/diagnose-boot.sh"
echo "4. Consulter /var/log/pi-signage-boot-diagnose.log"
echo ""
echo "Pour réactiver les services après diagnostic:"
echo "sudo systemctl enable vlc-signage  # ou chromium-kiosk selon votre choix"
echo "sudo systemctl enable lightdm"