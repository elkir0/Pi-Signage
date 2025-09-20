# 🛠️ Guide de Dépannage - Pi-Signage v0.9.0

## Problèmes Fréquents et Solutions

### 1. Écran noir au démarrage

**Symptôme** : L'écran reste noir après le boot

**Solutions** :
```bash
# Vérifier si X est démarré
ps aux | grep Xorg

# Si non, démarrer manuellement
startx

# Vérifier les logs
cat /var/log/Xorg.0.log | grep EE
```

### 2. Vidéo ne démarre pas

**Symptôme** : X démarre mais pas de vidéo

**Solutions** :
```bash
# Vérifier VLC
/opt/pisignage/scripts/vlc-control.sh status

# Relancer VLC
/opt/pisignage/scripts/vlc-control.sh restart

# Vérifier les vidéos
ls -la /opt/pisignage/media/
```

### 3. Performance dégradée (<30 FPS)

**Symptôme** : Vidéo saccadée

**Solutions** :
```bash
# Vérifier throttling thermique
vcgencmd get_throttled
# Si != 0x0, problème de température ou alimentation

# Vérifier température
vcgencmd measure_temp
# Si > 70°C, ajouter ventilation

# Vérifier alimentation
dmesg | grep voltage
# Chercher "Under-voltage"
```

### 4. Interface web inaccessible

**Symptôme** : Erreur 404 ou connexion refusée

**Solutions** :
```bash
# Vérifier nginx
sudo systemctl status nginx
sudo systemctl restart nginx

# Vérifier PHP
sudo systemctl status php8.2-fpm
sudo systemctl restart php8.2-fpm

# Vérifier permissions
sudo chown -R www-data:www-data /opt/pisignage/web
```

### 5. Upload de vidéos échoue

**Symptôme** : Erreur lors de l'upload via l'interface

**Solutions** :
```bash
# Vérifier l'espace disque
df -h

# Vérifier permissions
sudo chmod 775 /opt/pisignage/media
sudo chown www-data:www-data /opt/pisignage/media

# Augmenter limite PHP
sudo nano /etc/php/8.2/fpm/php.ini
# upload_max_filesize = 500M
# post_max_size = 500M
sudo systemctl restart php8.2-fpm
```

### 6. VLC crash régulièrement

**Symptôme** : VLC se ferme inopinément

**Solutions** :
```bash
# Vérifier les logs
tail -f /opt/pisignage/logs/vlc.log

# Tester avec une vidéo simple
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30:duration=10 \
       -c:v h264 /tmp/test.mp4
/opt/pisignage/scripts/vlc-control.sh start /tmp/test.mp4

# Réinstaller VLC
sudo apt-get install --reinstall vlc vlc-plugin-base
```

### 7. Boot automatique ne fonctionne pas

**Symptôme** : Doit se connecter manuellement

**Solutions** :
```bash
# Vérifier auto-login
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf

# Reconfigurer
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << AUTO
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
AUTO

# Vérifier .bash_profile
cat /home/pi/.bash_profile
```

## Commandes Utiles

### Monitoring
```bash
# CPU et mémoire
htop

# Température
watch vcgencmd measure_temp

# Utilisation disque
df -h

# Logs système
journalctl -xe
```

### Reset Complet
```bash
# Arrêter tous les services
sudo systemctl stop nginx php8.2-fpm
pkill vlc

# Nettoyer
rm -rf /opt/pisignage/logs/*
rm /tmp/vlc.pid

# Redémarrer
sudo reboot
```

## Support

Si le problème persiste :
1. Collecter les logs : `sudo journalctl -b > debug.log`
2. Créer une issue : https://github.com/elkir0/Pi-Signage/issues
3. Inclure : Version Pi, OS, logs, étapes reproduire
