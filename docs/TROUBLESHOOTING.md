# Guide de dépannage - PiSignage v0.8.1

## Vue d'ensemble

Ce guide présente les solutions aux problèmes les plus fréquents rencontrés lors de l'utilisation de PiSignage v0.8.1. Les problèmes sont classés par catégorie avec des procédures de résolution détaillées.

---

## Problèmes d'installation

### Le script d'installation se bloque pendant la mise à jour système

**Symptômes observés :**
- Le script reste bloqué sur la commande `apt upgrade`
- Des messages d'erreur de configuration de packages apparaissent

**Procédure de résolution :**
```bash
# Résoudre les conflits de packages
sudo apt update --fix-missing
sudo dpkg --configure -a
sudo apt install -f

# Relancer l'installation
bash install.sh --auto
```

### Erreurs de permissions pendant l'installation

**Symptômes observés :**
- Messages `Permission denied` lors de la création de fichiers
- Erreurs d'accès au répertoire `/opt/pisignage/`

**Procédure de résolution :**
```bash
# Vérifier que vous n'êtes pas connecté en tant que root
whoami  # La commande ne doit pas retourner 'root'

# Corriger les permissions du répertoire
sudo mkdir -p /opt/pisignage
sudo chown -R $USER:$USER /opt/pisignage
sudo chmod 755 /opt/pisignage

# Relancer l'installation
bash install.sh --auto
```

### Échec du téléchargement des dépendances

**Symptômes observés :**
- Le téléchargement des packages échoue
- Erreurs de connexion réseau pendant l'installation

**Procédure de résolution :**
```bash
# Vérifier la connectivité Internet
ping -c 4 8.8.8.8

# Si nécessaire, utiliser un miroir français plus proche
sudo sed -i 's/http:\/\/deb.debian.org/http:\/\/ftp.fr.debian.org/g' /etc/apt/sources.list

# Relancer l'installation avec plusieurs tentatives
for i in {1..3}; do
    bash install.sh --auto && break
    sleep 10
done
```

---

## Problèmes de service

### Le service PiSignage refuse de démarrer

**Symptômes observés :**
- La commande `systemctl status pisignage` affiche un état "failed"
- Le lecteur vidéo ne se lance pas automatiquement au démarrage

**Phase de diagnostic :**
```bash
# Examiner les logs en temps réel
sudo journalctl -u pisignage -f

# Tester manuellement le gestionnaire de lecteur
sudo -u pi /opt/pisignage/scripts/player-manager-v0.8.1.sh test

# Vérifier l'environnement graphique
echo $DISPLAY  # Doit afficher :0
ps aux | grep -E "(Xorg|Wayland)"
```

**Procédures de résolution :**

**Première approche - Réinitialisation complète du service :**
```bash
sudo systemctl stop pisignage
sudo systemctl disable pisignage
sudo systemctl enable pisignage
sudo systemctl start pisignage
```

**Deuxième approche - Configuration de l'environnement systemd :**
```bash
sudo systemctl edit pisignage
# Ajouter les lignes suivantes dans l'éditeur :
# [Service]
# Environment=DISPLAY=:0
# Environment=XDG_RUNTIME_DIR=/run/user/1000
```

**Troisième approche - Vérification des permissions :**
```bash
sudo chown pi:pi /opt/pisignage/scripts/player-manager-v0.8.1.sh
sudo chmod +x /opt/pisignage/scripts/player-manager-v0.8.1.sh
```

### Le service se relance continuellement

**Symptômes observés :**
- Le service redémarre en boucle sans s'arrêter
- Les logs montrent des erreurs qui se répètent

**Phase de diagnostic :**
```bash
# Analyser l'historique des redémarrages
sudo systemctl status pisignage | grep -i restart

# Examiner les logs récents
sudo journalctl -u pisignage --since="10 minutes ago"
```

**Procédures de résolution :**

**Augmentation des délais de redémarrage :**
```bash
sudo systemctl edit pisignage
# Ajouter dans l'éditeur :
# [Service]
# RestartSec=30
# StartLimitInterval=300
# StartLimitBurst=3
```

**Désactivation temporaire du redémarrage automatique :**
```bash
sudo systemctl edit pisignage
# Ajouter dans l'éditeur :
# [Service]
# Restart=no
```

---

## Problèmes de lecteurs vidéo

### VLC refuse de se lancer

**Symptômes observés :**
- L'écran reste complètement noir
- Les logs de VLC contiennent des messages d'erreur

**Phase de diagnostic :**
```bash
# Vérifier l'installation de VLC
cvlc --version
which cvlc

# Test de lecture manuel
export DISPLAY=:0
cvlc --intf dummy --fullscreen /opt/pisignage/media/BigBuckBunny_720p.mp4

# Vérifier les processus en cours
ps aux | grep vlc
```

**Procédures de résolution :**

**Réinitialisation de la configuration VLC :**
```bash
rm -rf /home/pi/.config/vlc
mkdir -p /home/pi/.config/vlc
cat > /home/pi/.config/vlc/vlcrc << 'EOF'
[core]
intf=dummy
vout=drm
fullscreen=1
loop=1
no-video-title-show=1
quiet=1
EOF
```

**Configuration de la sortie vidéo :**
```bash
# Vérifier et modifier le script de lancement si nécessaire
/opt/pisignage/scripts/start-vlc.sh
# Le script doit inclure l'option --vout drm
```

**Vérification de l'accélération matérielle :**
```bash
vcgencmd get_config int | grep gpu_mem
# La valeur doit être d'au moins 64MB
```

### MPV ne fonctionne pas correctement

**Symptômes observés :**
- MPV se ferme immédiatement après le lancement
- Aucune sortie vidéo n'apparaît à l'écran

**Phase de diagnostic :**
```bash
# Vérifier l'installation et les capacités de MPV
mpv --version
mpv --vo=help

# Test de lecture avec un fichier spécifique
export DISPLAY=:0
mpv --vo=drm --hwdec=auto /opt/pisignage/media/BigBuckBunny_720p.mp4 --really-quiet --length=5
```

**Procédures de résolution :**

**Configuration optimisée de MPV :**
```bash
mkdir -p /home/pi/.config/mpv
cat > /home/pi/.config/mpv/mpv.conf << 'EOF'
vo=drm
hwdec=drm-copy
fullscreen=yes
loop-playlist=inf
quiet=yes
no-terminal=yes
no-input-default-bindings=yes
EOF
```

**Vérification du support DRM :**
```bash
ls -la /dev/dri/
# Le répertoire doit contenir au minimum card0
```

**Test des différentes sorties vidéo :**
```bash
mpv --vo=gpu --gpu-context=drm /opt/pisignage/media/BigBuckBunny_720p.mp4
```

### Le basculement entre VLC et MPV ne fonctionne pas

**Symptômes observés :**
- L'interface continue d'afficher le même lecteur
- Les commandes de changement de lecteur échouent

**Phase de diagnostic :**
```bash
# Examiner la configuration actuelle
cat /opt/pisignage/config/player-config.json | jq .

# Tester manuellement le script de basculement
/opt/pisignage/scripts/player-manager-v0.8.1.sh switch
```

**Procédures de résolution :**

**Restauration de la configuration par défaut :**
```bash
cp /opt/pisignage/config/player-config.json /opt/pisignage/config/player-config.json.backup
wget -O /opt/pisignage/config/player-config.json \
    https://raw.githubusercontent.com/elkir0/Pi-Signage/main/config/player-config.json
```

**Correction des permissions sur les scripts :**
```bash
chmod +x /opt/pisignage/scripts/*.sh
chown pi:pi /opt/pisignage/scripts/*.sh
```

**Test individuel des lecteurs :**
```bash
sudo -u pi cvlc --intf dummy --version
sudo -u pi mpv --version
```

---

## Problèmes d'interface web

### La page web ne se charge pas

**Symptômes observés :**
- Le navigateur affiche une erreur 502 ou 503
- Délai d'attente de connexion dépassé

**Phase de diagnostic :**
```bash
# Vérifier l'état des services web
sudo systemctl status nginx php8.2-fpm

# Tester l'accès local au serveur web
curl -I http://localhost
curl -v http://localhost

# Examiner les logs d'erreur
tail -f /var/log/nginx/error.log
tail -f /var/log/php8.2-fpm.log
```

**Procédures de résolution :**

**Redémarrage des services web :**
```bash
sudo systemctl restart nginx php8.2-fpm
```

**Vérification et correction de la configuration Nginx :**
```bash
sudo nginx -t
sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
```

**Correction des permissions sur les fichiers web :**
```bash
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chmod -R 755 /opt/pisignage/web
```

### L'API ne répond pas aux requêtes

**Symptômes observés :**
- Erreurs JavaScript visibles dans la console du navigateur
- Les endpoints de l'API retournent des codes d'erreur

**Phase de diagnostic :**
```bash
# Tester individuellement chaque endpoint
curl http://localhost/api/system.php
curl http://localhost/api/player.php
curl http://localhost/api/media.php

# Vérifier les permissions sur les fichiers API
ls -la /opt/pisignage/web/api/
```

**Procédures de résolution :**

**Retéléchargement des fichiers API :**
```bash
cd /opt/pisignage/web/api
for api in system player media screenshot; do
    wget -O ${api}.php \
        https://raw.githubusercontent.com/elkir0/Pi-Signage/main/web/api/${api}.php
done
```

**Correction des permissions PHP :**
```bash
sudo chown www-data:www-data /opt/pisignage/web/api/*.php
sudo chmod 644 /opt/pisignage/web/api/*.php
```

**Vérification des modules PHP requis :**
```bash
php -m | grep -E "(json|curl|gd)"
```

### L'upload de fichiers média échoue

**Symptômes observés :**
- Message d'erreur "File too large" lors de l'upload
- Transfer interrompu avant la fin

**Phase de diagnostic :**
```bash
# Examiner les limites configurées dans PHP
php -i | grep -E "(upload_max_filesize|post_max_size|max_execution_time)"

# Vérifier l'espace disque disponible
df -h /opt/pisignage/media/
```

**Procédures de résolution :**

**Augmentation des limites PHP :**
```bash
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/fpm/php.ini
sudo systemctl restart php8.2-fpm
```

**Configuration du répertoire temporaire :**
```bash
sudo mkdir -p /tmp/nginx_uploads
sudo chown www-data:www-data /tmp/nginx_uploads
```

**Vérification des permissions sur le dossier média :**
```bash
sudo chown www-data:www-data /opt/pisignage/media
sudo chmod 755 /opt/pisignage/media
```

---

## Problèmes d'affichage

### Écran noir ou absence totale d'affichage

**Symptômes observés :**
- L'écran reste complètement noir
- Aucun signal vidéo n'est détecté par l'écran ou le téléviseur

**Phase de diagnostic :**
```bash
# Vérifier l'état de la sortie vidéo
vcgencmd display_power
tvservice -s

# Contrôler les processus de lecture vidéo
ps aux | grep -E "(vlc|mpv)"

# Tenter une réactivation manuelle de l'affichage
export DISPLAY=:0
xset dpms force on
```

**Procédures de résolution :**

**Réactivation de la sortie vidéo :**
```bash
vcgencmd display_power 1
tvservice -p
```

**Configuration forcée de la sortie HDMI :**
```bash
echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
sudo reboot
```

**Test automatique de différentes résolutions :**
```bash
for mode in 16 4 1; do
    tvservice -e "CEA $mode"
    sleep 5
    if vcgencmd display_power | grep -q "1"; then
        echo "Mode $mode fonctionne correctement"
        break
    fi
done
```

### Image déformée ou partiellement coupée

**Symptômes observés :**
- La vidéo apparaît étirée ou écrasée
- Les bords de l'image sont coupés (problème d'overscan)

**Procédures de résolution :**

**Désactivation de l'overscan :**
```bash
sudo sed -i 's/#disable_overscan=1/disable_overscan=1/' /boot/config.txt
sudo reboot
```

**Configuration du ratio d'aspect pour VLC :**
```bash
cat > /home/pi/.config/vlc/vlcrc << 'EOF'
[core]
intf=dummy
vout=drm
fullscreen=1
video-on-top=1
aspect-ratio=16:9
EOF
```

**Configuration du ratio d'aspect pour MPV :**
```bash
cat > /home/pi/.config/mpv/mpv.conf << 'EOF'
vo=drm
fullscreen=yes
video-aspect-override=16:9
keepaspect=yes
EOF
```

### Absence de son

**Symptômes observés :**
- La vidéo s'affiche correctement mais aucun son n'est audible
- L'audio semble coupé ou en sourdine

**Phase de diagnostic :**
```bash
# Lister les périphériques audio disponibles
aplay -l
amixer scontrols

# Vérifier les niveaux de volume
amixer get Master
```

**Procédures de résolution :**

**Configuration de la sortie audio HDMI :**
```bash
amixer cset numid=3 2  # Force l'audio HDMI
sudo alsactl store
```

**Configuration audio spécifique pour VLC :**
```bash
cat >> /home/pi/.config/vlc/vlcrc << 'EOF'
[alsa]
alsa-audio-device=hw:0,1

[core]
aout=alsa
EOF
```

**Configuration système audio globale :**
```bash
echo "defaults.pcm.card 0" | sudo tee -a /etc/asound.conf
echo "defaults.ctl.card 0" | sudo tee -a /etc/asound.conf
```

---

## Problèmes de performance

### Lenteur générale du système

**Symptômes observés :**
- L'interface web répond très lentement
- La lecture vidéo est saccadée
- Le système semble globalement ralenti

**Phase de diagnostic :**
```bash
# Analyser l'utilisation des ressources système
htop
iotop -ao
df -h

# Contrôler la température et les limitations thermiques
vcgencmd measure_temp
vcgencmd get_throttled
```

**Procédures d'optimisation :**

**Optimisation de la mémoire GPU :**
```bash
echo "gpu_mem=128" | sudo tee -a /boot/config.txt
sudo reboot
```

**Désactivation du swap pour améliorer les performances :**
```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

**Nettoyage de l'espace disque :**
```bash
sudo apt autoremove -y
sudo apt autoclean
sudo find /tmp -type f -atime +7 -delete
```

### Lecture vidéo saccadée ou instable

**Symptômes observés :**
- La vidéo présente des à-coups ou des ralentissements
- Des images sautent pendant la lecture

**Procédures d'optimisation :**

**Optimisation des paramètres de cache pour VLC :**
```bash
cat > /home/pi/.config/vlc/vlcrc << 'EOF'
[core]
intf=dummy
vout=mmal_xsplitter
file-caching=3000
network-caching=3000
sout-mux-caching=3000
EOF
```

**Optimisation des paramètres de cache pour MPV :**
```bash
cat > /home/pi/.config/mpv/mpv.conf << 'EOF'
vo=drm
hwdec=drm-copy
cache=yes
demuxer-max-bytes=50M
cache-default=8000
EOF
```

**Overclocking modéré (uniquement pour Raspberry Pi 3) :**
```bash
echo "arm_freq=1300" | sudo tee -a /boot/config.txt
echo "core_freq=500" | sudo tee -a /boot/config.txt
```

---

## Problèmes réseau

### Interface web inaccessible depuis le réseau local

**Symptômes observés :**
- L'interface est accessible localement mais pas depuis d'autres ordinateurs
- Délais d'attente lors des tentatives de connexion réseau

**Phase de diagnostic :**
```bash
# Vérifier l'adresse IP et l'état des ports
ip addr show
netstat -tlnp | grep :80

# Test de connectivité depuis un autre ordinateur :
# telnet [IP_DU_RASPBERRY] 80
```

**Procédures de résolution :**

**Vérification et configuration du pare-feu :**
```bash
sudo ufw status
sudo ufw allow 80/tcp
```

**Contrôle de la configuration réseau de Nginx :**
```bash
sudo netstat -tlnp | grep nginx
sudo nginx -T | grep listen
```

**Redémarrage des services réseau :**
```bash
sudo systemctl restart networking
sudo systemctl restart nginx
```

---

## Outils de diagnostic

### Script de diagnostic automatique

Ce script génère un rapport complet de l'état du système :

```bash
# Création du script de diagnostic
cat > /opt/pisignage/scripts/diagnostic.sh << 'EOF'
#!/bin/bash
echo "=== Rapport de diagnostic PiSignage v0.8.1 ==="
echo "Date du diagnostic: $(date)"
echo "Temps de fonctionnement: $(uptime)"
echo ""

echo "=== Informations système ==="
echo "Système d'exploitation: $(lsb_release -d | cut -f2)"
echo "Version du noyau: $(uname -r)"
echo "Modèle de Raspberry Pi: $(grep Model /proc/cpuinfo | cut -d: -f2 | xargs)"
echo "Température: $(vcgencmd measure_temp)"
echo "Mémoire GPU: $(vcgencmd get_config gpu_mem | cut -d= -f2)M"
echo ""

echo "=== État des services ==="
systemctl is-active nginx && echo "✓ Nginx: Actif" || echo "✗ Nginx: Inactif"
systemctl is-active php8.2-fpm && echo "✓ PHP-FPM: Actif" || echo "✗ PHP-FPM: Inactif"
systemctl is-active pisignage && echo "✓ PiSignage: Actif" || echo "✗ PiSignage: Inactif"
echo ""

echo "=== Lecteurs vidéo ==="
pgrep vlc > /dev/null && echo "✓ VLC: En fonctionnement" || echo "✗ VLC: Arrêté"
pgrep mpv > /dev/null && echo "✓ MPV: En fonctionnement" || echo "✗ MPV: Arrêté"
echo ""

echo "=== Configuration réseau ==="
echo "Adresse IP: $(hostname -I | awk '{print $1}')"
netstat -tlnp | grep :80 > /dev/null && echo "✓ Port 80: Ouvert" || echo "✗ Port 80: Fermé"
curl -s -o /dev/null -w "%{http_code}" http://localhost && echo "✓ Interface web: Accessible" || echo "✗ Interface web: Inaccessible"
echo ""

echo "=== Utilisation du stockage ==="
df -h / | tail -1 | awk '{print "Partition racine: " $3 " utilisés sur " $2 " (" $5 " plein)"}'
df -h /opt/pisignage/media | tail -1 | awk '{print "Dossier média: " $3 " utilisés sur " $2 " (" $5 " plein)"}'
echo ""

echo "=== Journaux récents ==="
echo "Dernières erreurs Nginx :"
tail -5 /var/log/nginx/error.log 2>/dev/null || echo "Aucune erreur trouvée"
echo ""
echo "Derniers événements du service PiSignage :"
journalctl -u pisignage --no-pager -n 5 2>/dev/null || echo "Aucun journal disponible"
EOF

chmod +x /opt/pisignage/scripts/diagnostic.sh
```

### Script de collecte de logs pour le support technique

Ce script rassemble tous les logs nécessaires pour un diagnostic approfondi :

```bash
# Création du script de collecte de logs
cat > /opt/pisignage/scripts/collect-logs.sh << 'EOF'
#!/bin/bash
LOGDIR="/tmp/pisignage-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p $LOGDIR

echo "Collecte des informations de diagnostic..."
# Rapport de diagnostic complet
/opt/pisignage/scripts/diagnostic.sh > $LOGDIR/diagnostic.txt

echo "Extraction des journaux système..."
# Journaux des services système
journalctl -u pisignage --no-pager > $LOGDIR/pisignage-service.log
journalctl -u nginx --no-pager > $LOGDIR/nginx-service.log
journalctl -u php8.2-fpm --no-pager > $LOGDIR/php-service.log

echo "Copie des logs applicatifs..."
# Logs des applications
cp /var/log/nginx/error.log $LOGDIR/ 2>/dev/null
cp /opt/pisignage/logs/*.log $LOGDIR/ 2>/dev/null

echo "Sauvegarde des configurations..."
# Fichiers de configuration
cp /opt/pisignage/config/*.json $LOGDIR/ 2>/dev/null
nginx -T > $LOGDIR/nginx-config.txt 2>&1
php --ini > $LOGDIR/php-config.txt

echo "Création de l'archive..."
# Génération de l'archive compressée
cd /tmp
tar -czf pisignage-logs-$(basename $LOGDIR).tar.gz $(basename $LOGDIR)
echo "Archive créée : /tmp/pisignage-logs-$(basename $LOGDIR).tar.gz"
rm -rf $LOGDIR
EOF

chmod +x /opt/pisignage/scripts/collect-logs.sh
```

---

## Ressources et support

### Fichiers de journalisation importants

Voici l'emplacement des principaux fichiers de logs pour le diagnostic :

- **Service PiSignage** : `journalctl -u pisignage -f`
- **Serveur web Nginx** : `/var/log/nginx/error.log`
- **Processeur PHP-FPM** : `/var/log/php8.2-fpm.log`
- **Lecteur VLC** : `/opt/pisignage/logs/vlc.log`
- **Lecteur MPV** : `/opt/pisignage/logs/mpv.log`
- **Système PiSignage** : `/opt/pisignage/logs/pisignage.log`

### Commandes de maintenance courantes

```bash
# Redémarrage de tous les services PiSignage
sudo systemctl restart nginx php8.2-fpm pisignage

# Vérification rapide de l'état de tous les services
sudo systemctl status nginx php8.2-fpm pisignage

# Arrêt forcé des processus de lecture bloqués
sudo pkill -9 vlc mpv

# Test de fonctionnement de l'interface web
curl -I http://localhost

# Surveillance en temps réel des lecteurs vidéo
watch -n 5 'ps aux | grep -E "(vlc|mpv)" | grep -v grep'
```

### Ressources de support

**Canaux de support officiels :**
- **Signalement de problèmes** : https://github.com/elkir0/Pi-Signage/issues
- **Documentation complète** : `/opt/pisignage/docs/`
- **Script de diagnostic** : `/opt/pisignage/scripts/diagnostic.sh`

**Avant de demander de l'aide :**
Exécutez systématiquement le script de diagnostic et incluez les logs générés dans votre demande de support. Cette information permet d'accélérer considérablement la résolution des problèmes.