# Guide de dépannage - Blocage au démarrage

## Symptômes

Le Raspberry Pi se bloque pendant le boot avec des messages comme :
- `Finished console-setup.service - Set console font and keymap`
- `Starting systemd-tmpfiles-setup.service`
- Pas de prompt de connexion

## Causes possibles

1. **Service bloquant** : Un service (VLC, Chromium, LightDM) empêche la fin du boot
2. **Problème graphique** : Conflit entre le mode console et le mode graphique
3. **Espace disque plein** : Pas assez d'espace pour les logs ou fichiers temporaires
4. **Corruption de la carte SD** : Secteurs défectueux suite à coupure de courant

## Solutions

### Solution 1 : Mode Recovery (Recommandé)

1. **Accéder au mode recovery** :
   - Maintenir SHIFT pendant le boot
   - OU éditer cmdline.txt sur un autre PC et ajouter `init=/bin/bash` à la fin

2. **Une fois en mode recovery** :
   ```bash
   # Monter le système en lecture/écriture
   mount -o remount,rw /
   
   # Désactiver temporairement les services
   systemctl disable vlc-signage
   systemctl disable chromium-kiosk
   systemctl disable lightdm
   
   # Redémarrer
   reboot
   ```

### Solution 2 : Depuis un autre ordinateur

1. **Retirer la carte SD** et la monter sur un PC Linux

2. **Exécuter le script de réparation** :
   ```bash
   # Télécharger le script
   wget https://raw.githubusercontent.com/elkir0/Pi-Signage/main/raspberry-pi-installer/scripts/emergency-boot-fix.sh
   
   # Le rendre exécutable et l'exécuter
   chmod +x emergency-boot-fix.sh
   ./emergency-boot-fix.sh
   ```

3. **Suivre les instructions** du script

### Solution 3 : Connexion SSH (si activé)

Si SSH était activé avant le problème :
```bash
# Essayer de se connecter même si l'écran est bloqué
ssh pi@[IP_DU_PI]

# Une fois connecté
sudo systemctl stop vlc-signage
sudo systemctl stop chromium-kiosk
sudo systemctl disable vlc-signage
sudo systemctl disable chromium-kiosk
```

## Diagnostic après réparation

Une fois le Pi démarré :

```bash
# Vérifier les services en échec
sudo systemctl --failed

# Voir les logs de boot
sudo journalctl -b -p err

# Vérifier l'espace disque
df -h

# Vérifier quel service bloquait
sudo systemctl status vlc-signage
sudo systemctl status chromium-kiosk
sudo systemctl status lightdm
```

## Réactivation des services

Après diagnostic et correction :

```bash
# Pour VLC Classic
sudo systemctl enable lightdm
sudo systemctl enable vlc-signage
sudo systemctl start lightdm

# OU pour Chromium Kiosk
sudo systemctl enable chromium-kiosk
sudo systemctl start chromium-kiosk
```

## Prévention

1. **Toujours tester** après installation :
   ```bash
   sudo systemctl start [service]
   # Attendre 30 secondes
   sudo systemctl status [service]
   ```

2. **Activer SSH** avant le premier reboot :
   ```bash
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```

3. **Créer un backup** de cmdline.txt :
   ```bash
   sudo cp /boot/cmdline.txt /boot/cmdline.txt.backup
   ```

## Logs utiles

- `/var/log/pi-signage-setup.log` : Installation
- `/var/log/syslog` : Logs système
- `/var/log/lightdm/` : Logs du display manager
- `journalctl -xe` : Logs détaillés du boot