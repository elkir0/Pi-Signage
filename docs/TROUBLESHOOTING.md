# Guide de dépannage - PiSignage v0.12

## Vue d'ensemble

Ce guide présente les solutions aux problèmes les plus fréquents rencontrés lors de l'utilisation de PiSignage v0.12. Depuis cette version, le moteur de lecture est **unique : Chromium HTML5 en mode kiosk Wayland** (la page `web/player.php` servie sur `/player`). VLC a été entièrement retiré (plus de service `pisignage-vlc`, plus d'interface HTTP VLC sur le port 8080, plus de « volume VLC »). Ce guide se concentre donc sur le dépannage du kiosk Chromium, de l'API de contrôle du lecteur et de la programmation (dayparting).

### Architecture de lecture v0.12
- **Moteur unique Chromium HTML5**: `chromium --kiosk http://127.0.0.1/player`, lit `/opt/pisignage/media/playlist.json`
- **Session graphique lightdm**: autologin `pi` → compositeur Wayland `labwc` → Chromium kiosk (PAS greetd)
- **Contrôle du lecteur via API**: `web/api/display.php` (commandes `next|prev|play|pause|reload`, état live, lecture média isolé)
- **Volume = ALSA système**: via `web/api/system.php` (`set_volume`/`get_volume`/`toggle_mute`)
- **Playlists unifiées**: `web/api/playlists.php`, une seule source de vérité (`/opt/pisignage/playlists/<slug>.json`)
- **Programmation réelle (dayparting)**: `web/api/scheduler.php` lancé par cron 1×/minute
- **Cible**: Raspberry Pi 4/5, Raspberry Pi OS Trixie (Debian 13), Wayland/labwc, PHP 8.4-fpm + nginx

---

## Problèmes spécifiques v0.12

### Navigation entre pages qui ne fonctionne pas

**Symptômes observés :**
- Navigation entre pages qui échoue
- Pages qui ne se chargent pas correctement

**Solution :**
```bash
# Vider le cache du navigateur
# Ctrl+Shift+Delete ou Cmd+Shift+Delete

# Accès direct aux pages modulaires
http://[IP-PI]/dashboard.php
http://[IP-PI]/media.php
http://[IP-PI]/playlists.php          # composer + Diffuser à l'écran
http://[IP-PI]/player-control-ui.php  # page « Lecteur » : contrôle du moteur réel (play/pause/skip/reload + volume ALSA)
http://[IP-PI]/settings.php
```

### Performance dégradée après migration

**Diagnostic :**
```bash
# Tester le chargement des pages
time curl -s http://localhost/dashboard.php > /dev/null

# Vérifier le moteur de lecture Chromium kiosk
ps aux | grep chromium
```

**Solution :**
```bash
# Vider tous les caches
sudo systemctl restart nginx php8.4-fpm

# Forcer le rechargement CSS/JS
rm -rf /opt/pisignage/web/assets/cache/* 2>/dev/null

# Redémarrer la session graphique (relance le kiosk Chromium)
sudo systemctl restart display-manager
```

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

## Problèmes de session graphique (kiosk)

> **v0.12**: Il n'y a plus de service systemd `pisignage`/`pisignage-vlc`. Le « lecteur » est la session graphique : `lightdm` (display-manager) auto-logge l'utilisateur `pi`, lance le compositeur Wayland `labwc`, qui démarre Chromium en mode kiosk sur `http://127.0.0.1/player`.

### La session graphique ne démarre pas

**Symptômes observés :**
- Écran noir au démarrage
- Aucun navigateur affiché
- Le kiosk Chromium ne se lance pas automatiquement

**Phase de diagnostic :**
```bash
# État du gestionnaire d'affichage (lightdm)
sudo systemctl status display-manager
sudo journalctl -u lightdm -n 50

# Vérifier l'environnement graphique Wayland
echo $WAYLAND_DISPLAY
ps aux | grep -E "(labwc|chromium)"

# Vérifier les logs de la session utilisateur
journalctl --user -xe
```

**Procédures de résolution :**

**Première approche - Redémarrer la session graphique :**
```bash
# Relance lightdm → labwc → Chromium kiosk (« Redémarrer la session »)
sudo systemctl restart display-manager
```

**Deuxième approche - Vérifier que lightdm est bien activé :**
```bash
sudo systemctl enable lightdm
sudo systemctl status display-manager   # doit pointer vers lightdm.service
```

**Troisième approche - Régénérer la configuration kiosk :**
```bash
# Régénère l'autostart labwc à partir de la config
/opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager
```

### Le kiosk Chromium se relance en boucle

**Symptômes observés :**
- L'écran clignote / Chromium réapparaît sans cesse
- Les logs de session montrent des erreurs qui se répètent

**Phase de diagnostic :**
```bash
# Examiner les logs de la session utilisateur
journalctl --user --since="10 minutes ago"

# Vérifier l'autostart labwc et l'URL kiosk
cat ~/.config/labwc/autostart
cat /opt/pisignage/config/kiosk_url

# Vérifier que /player répond bien en local
curl -I http://127.0.0.1/player
```

**Procédures de résolution :**

**Vérifier que la pile web fonctionne (sinon /player renvoie une erreur et Chromium boucle) :**
```bash
sudo systemctl status nginx php8.4-fpm
sudo systemctl restart nginx php8.4-fpm
```

**Tester la page kiosk dans une session contrôlée :**
```bash
# Tuer Chromium pour forcer une relance propre
pkill -f "/usr/bin/chromium"
```

---

## Problèmes du lecteur (Chromium HTML5)

> **v0.12**: Le moteur de lecture est uniquement Chromium en mode kiosk affichant `/player`. Il n'y a plus de VLC ni de MPV.

### La page /player ne s'affiche pas (écran noir / page d'erreur)

**Symptômes observés :**
- L'écran reste noir ou affiche une page d'erreur du navigateur
- Le splash PiSignage ne disparaît jamais
- Aucun média ne tourne

**Phase de diagnostic :**
```bash
# Vérifier que Chromium kiosk tourne
ps aux | grep chromium

# Vérifier l'URL kiosk configurée (doit pointer vers /player en local)
cat /opt/pisignage/config/kiosk_url
# Attendu : http://127.0.0.1/player

# Tester /player en local
curl -I http://127.0.0.1/player

# Vérifier que la playlist à l'écran existe et est valide
cat /opt/pisignage/media/playlist.json | head
```

**Procédures de résolution :**

**Corriger l'URL kiosk et régénérer l'autostart :**
```bash
echo "http://127.0.0.1/player" | sudo tee /opt/pisignage/config/kiosk_url
/opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager
```

**Vérifier la pile web (nginx + PHP) qui sert /player :**
```bash
sudo systemctl status nginx php8.4-fpm
sudo nginx -t
sudo systemctl restart nginx php8.4-fpm
curl -I http://127.0.0.1/player
```

**Vérifier l'accélération matérielle (rendu vidéo HTML5) :**
```bash
vcgencmd get_config int | grep gpu_mem
# La valeur doit être d'au moins 64MB
```

### Le lecteur ne répond pas aux commandes (play/pause/skip/reload)

**Symptômes observés :**
- Les boutons de la page « Lecteur » (play/pause/next/prev/reload) restent sans effet
- L'état live ne se met pas à jour dans l'UI

**Rappel du fonctionnement (v0.12) :**
- L'admin POST une commande sur `web/api/display.php` : `POST ?action=command {cmd:next|prev|play|pause|reload}`
- Le player (page `/player`) poll `GET ?action=command` toutes les 2s, exécute la commande, puis rapporte son état via `POST ?action=state`
- L'admin lit l'état live via `GET ?action=state`
- Lecture d'un média isolé : `POST ?action=playmedia {file}`

**Phase de diagnostic :**
```bash
# Lire l'état rapporté par le player
curl 'http://localhost/api/display.php?action=state'

# Envoyer une commande de test (next)
curl -X POST 'http://localhost/api/display.php?action=command' \
  -H "Content-Type: application/json" -d '{"cmd":"next"}'

# Vérifier le fichier de commande partagé et ses permissions
ls -la /opt/pisignage/config/player-command.json

# Vérifier les logs PHP/nginx
sudo tail -f /var/log/nginx/error.log
```

**Procédures de résolution :**

**Corriger les permissions du fichier de commande / d'état :**
```bash
# www-data (PHP) doit pouvoir lire/écrire player-command.json
sudo chown www-data:www-data /opt/pisignage/config/player-command.json
sudo chmod 664 /opt/pisignage/config/player-command.json
```

**Forcer le player à recharger (si le poll semble figé) :**
```bash
curl -X POST 'http://localhost/api/display.php?action=command' \
  -H "Content-Type: application/json" -d '{"cmd":"reload"}'

# Ou relancer la session graphique si le navigateur ne poll plus
sudo systemctl restart display-manager
```

**Vérifier le volume (volume SYSTÈME ALSA, pas « volume VLC ») :**
```bash
# Lecture de l'état du volume
curl 'http://localhost/api/system.php?action=get_volume'

# Réglage du volume (ALSA)
curl -X POST 'http://localhost/api/system.php?action=set_volume' \
  -H "Content-Type: application/json" -d '{"volume":80}'
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
sudo systemctl status nginx php8.4-fpm

# Tester l'accès local au serveur web
curl -I http://localhost
curl -v http://localhost

# Examiner les logs d'erreur
tail -f /var/log/nginx/error.log
tail -f /var/log/php8.4-fpm.log
```

**Procédures de résolution :**

**Redémarrage des services web :**
```bash
sudo systemctl restart nginx php8.4-fpm
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
# Tester individuellement chaque endpoint actif (v0.12)
curl http://localhost/api/system.php
curl 'http://localhost/api/display.php?action=state'
curl http://localhost/api/playlists.php
curl http://localhost/api/media.php

# Endpoints DÉPRÉCIÉS : doivent répondre HTTP 410 Gone
curl -I http://localhost/api/player.php
curl -I http://localhost/api/player-control.php
curl -I http://localhost/api/playlist-simple.php

# Vérifier les permissions sur les fichiers API
ls -la /opt/pisignage/web/api/
```

**Procédures de résolution :**

**Retéléchargement des fichiers API :**
```bash
cd /opt/pisignage/web/api
for api in system display media playlists screenshot; do
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
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' /etc/php/8.4/fpm/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' /etc/php/8.4/fpm/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.4/fpm/php.ini
sudo systemctl restart php8.4-fpm
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

# Contrôler le moteur de lecture (Chromium kiosk)
ps aux | grep chromium

# Réveiller l'affichage (Wayland/labwc — l'extinction d'écran est gérée
# par l'extinction programmée du kiosk ; relancer la session si besoin)
sudo systemctl restart display-manager
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

**Ajustement du cadrage côté player HTML5 :**
```bash
# Le cadrage de chaque média est défini dans la playlist (champ "fit" :
# contain | cover | fill) — voir l'éditeur de playlist dans l'UI.
# Inspecter la playlist active :
cat /opt/pisignage/media/playlist.json | python3 -m json.tool

# Forcer un échelonnage d'affichage via les flags Chromium (4K, etc.) :
echo "--kiosk --force-device-scale-factor=1" | sudo tee /opt/pisignage/config/kiosk_flags
/opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager
```

> **Note v0.12**: Le cadrage (aspect/zoom) n'est plus géré par un fichier de
> configuration VLC mais par le champ `fit` de chaque élément de playlist et
> par les flags Chromium. VLC a été retiré.

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

**Vérifier le volume système (ALSA) via l'API PiSignage :**
```bash
# Le son du player HTML5 suit le volume SYSTÈME ALSA (plus de « volume VLC »)
curl 'http://localhost/api/system.php?action=get_volume'
curl -X POST 'http://localhost/api/system.php?action=set_volume' \
  -H "Content-Type: application/json" -d '{"volume":80}'

# Vérifier que le média n'est pas en sourdine dans la playlist (champ "mute")
cat /opt/pisignage/media/playlist.json | grep -i mute
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

**Optimiser le rendu vidéo HTML5 (Chromium) :**
```bash
# Privilégier les médias H.264/MP4 (décodage matériel) ; éviter les codecs
# logiciels lourds (VP9/AV1 haute résolution) sur Pi 4.
# Le player précharge le média suivant pour éviter les "flashs" entre clips.

# Vérifier/ajuster les flags Chromium pour le rendu :
cat /opt/pisignage/config/kiosk_flags
echo "--kiosk --enable-features=VaapiVideoDecoder --ignore-gpu-blocklist" \
  | sudo tee /opt/pisignage/config/kiosk_flags
/opt/pisignage/scripts/kiosk-apply
sudo systemctl restart display-manager
```

> **Note v0.12**: Le cache de lecture VLC n'existe plus. La fluidité dépend du
> décodage matériel de Chromium et du format des médias. VLC a été retiré.

**Vérification de l'accélération matérielle GPU :**
```bash
vcgencmd get_config int | grep gpu_mem
# La valeur doit être d'au moins 128MB pour le décodage vidéo
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

## Problèmes spécifiques Trixie/Kiosk Mode

> **Note**: Cette section s'applique à Raspberry Pi OS Trixie (Debian 13). En v0.12 le kiosk Chromium est le moteur de lecture par défaut (affiche `/player`). La session est gérée par **lightdm** (display-manager), pas greetd.

### Chromium kiosk ne se lance pas

**Symptômes observés :**
- Écran noir au démarrage
- Chromium ne démarre pas automatiquement
- Session labwc sans navigateur

**Phase de diagnostic :**
```bash
# Vérifier si kiosk est activé
cat /opt/pisignage/config/feature_flags

# Vérifier processus Chromium
ps aux | grep chromium

# Vérifier configuration labwc
cat ~/.config/labwc/autostart

# Vérifier le gestionnaire d'affichage (lightdm) et les logs de session
sudo systemctl status display-manager
journalctl --user -xe
```

**Procédures de résolution :**

**Régénérer configuration kiosk :**
```bash
# Régénérer autostart labwc
/opt/pisignage/scripts/kiosk-apply

# Redémarrer la session (méthode propre) : lightdm → labwc → Chromium
sudo systemctl restart display-manager

# Ou tuer Chromium pour relance automatique
pkill -f "/usr/bin/chromium"
```

**Vérifier configuration réseau :**
```bash
# Chromium attend réseau (20s max)
# Vérifier connectivité
ping -c 3 1.1.1.1

# Vérifier URL kiosk
cat /opt/pisignage/config/kiosk_url

# Tester URL manuellement
curl -I $(cat /opt/pisignage/config/kiosk_url)
```

### Kiosk API ne répond pas

**Symptômes observés :**
- Erreurs 404 ou 500 sur `/api/kiosk.php`
- Impossibilité de changer URL/flags via API

**Phase de diagnostic :**
```bash
# Tester endpoint status
curl http://localhost/api/kiosk.php

# Vérifier permissions
ls -la /opt/pisignage/web/api/kiosk.php
ls -la /opt/pisignage/config/kiosk_*

# Vérifier logs PHP
sudo tail -f /var/log/nginx/error.log
```

**Procédures de résolution :**

**Corriger permissions :**
```bash
sudo chown www-data:www-data /opt/pisignage/web/api/kiosk.php
sudo chown www-data:www-data /opt/pisignage/config/kiosk_*
sudo chmod 644 /opt/pisignage/web/api/kiosk.php
sudo chmod 644 /opt/pisignage/config/kiosk_*
```

**Tester endpoints individuellement :**
```bash
# GET status
curl http://localhost/api/kiosk.php

# GET URL
curl http://localhost/api/kiosk.php/url

# GET flags
curl http://localhost/api/kiosk.php/flags
```

### Problèmes d'affichage Wayland

**Symptômes observés :**
- Résolution incorrecte
- Artefacts graphiques
- Performance dégradée

**Phase de diagnostic :**
```bash
# Vérifier session Wayland
echo $WAYLAND_DISPLAY

# Vérifier processus labwc
ps aux | grep labwc

# Vérifier flags Chromium actuels
cat /opt/pisignage/config/kiosk_flags
```

**Procédures de résolution :**

**Ajuster flags Chromium pour performance :**
```bash
# Via API
curl -X PUT http://localhost/api/kiosk.php/flags \
  -H "Content-Type: application/json" \
  -d '{"flags":"--incognito --noerrdialogs --disable-gpu-vsync"}'

# Ou manuellement
echo "--incognito --noerrdialogs --disable-gpu-vsync" | \
  sudo tee /opt/pisignage/config/kiosk_flags

/opt/pisignage/scripts/kiosk-apply
pkill -f chromium
```

**Ajuster pour affichage 4K :**
```bash
# Augmenter scale factor
curl -X PUT http://localhost/api/kiosk.php/flags \
  -H "Content-Type: application/json" \
  -d '{"flags":"--incognito --force-device-scale-factor=1.5 --high-dpi-support=1"}'
```

### Désactiver temporairement kiosk mode

> **v0.12**: Le kiosk Chromium est le seul moteur de lecture (VLC retiré). Désactiver le kiosk laisse la session graphique sans lecteur — à n'utiliser que pour la maintenance/diagnostic.

```bash
# Désactiver kiosk
echo "ENABLE_KIOSK=0" | sudo tee /opt/pisignage/config/feature_flags

# Redémarrer
sudo reboot

# Pour réactiver plus tard
echo "ENABLE_KIOSK=1" | sudo tee /opt/pisignage/config/feature_flags
sudo reboot
```

---

## Problèmes de programmation (dayparting)

> **v0.12**: La programmation est exécutée par `web/api/scheduler.php` en mode **CLI**, lancé par cron **1×/minute** (sous `www-data`, via `/etc/cron.d/pisignage-scheduler`). Il lit `/opt/pisignage/data/schedules.json`, désigne la playlist active selon heure/jour/récurrence/priorité (idempotent, revert en fin de fenêtre), et écrit l'état dans `/opt/pisignage/config/scheduler-state.json`.

### Les programmations ne se déclenchent pas

**Symptômes observés :**
- La playlist ne change pas à l'heure prévue
- Le badge « En cours » ne reflète pas la programmation
- `scheduler-state.json` ne se met pas à jour

**Phase de diagnostic :**
```bash
# Vérifier que le cron du scheduler est installé
cat /etc/cron.d/pisignage-scheduler

# Vérifier que cron tourne
systemctl status cron

# Lancer le scheduler manuellement (comme le ferait cron) et lire la sortie
sudo -u www-data php /opt/pisignage/web/api/scheduler.php

# Inspecter les programmations et l'état courant
cat /opt/pisignage/data/schedules.json | python3 -m json.tool
cat /opt/pisignage/config/scheduler-state.json
```

**Procédures de résolution :**

**Vérifier le fuseau horaire (cause fréquente) :**
```bash
# Le dayparting compare des heures LOCALES. PHP doit être aligné sur /etc/timezone
# (web/config.php force le fuseau PHP sur /etc/timezone).
cat /etc/timezone
date                      # heure locale du système
php -r 'echo date_default_timezone_get(), " ", date("H:i"), "\n";'

# Corriger le fuseau si nécessaire
sudo timedatectl set-timezone Europe/Brussels
sudo systemctl restart php8.4-fpm
```

**Corriger les permissions (www-data doit lire/écrire l'état) :**
```bash
sudo chown www-data:www-data /opt/pisignage/data/schedules.json
sudo chown www-data:www-data /opt/pisignage/config/scheduler-state.json
sudo chown www-data:www-data /opt/pisignage/config/active-playlist.json
sudo chmod 664 /opt/pisignage/config/scheduler-state.json
```

**Réinstaller le cron du scheduler :**
```bash
# Le cron exécute le scheduler chaque minute sous www-data
ls -la /etc/cron.d/pisignage-scheduler
sudo systemctl restart cron
```

---

## Outils de diagnostic

### Script de diagnostic automatique

Ce script génère un rapport complet de l'état du système :

```bash
# Création du script de diagnostic
cat > /opt/pisignage/scripts/diagnostic.sh << 'EOF'
#!/bin/bash
echo "=== Rapport de diagnostic PiSignage v0.12 ==="
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
systemctl is-active php8.4-fpm && echo "✓ PHP-FPM: Actif" || echo "✗ PHP-FPM: Inactif"
systemctl is-active display-manager && echo "✓ Session graphique (lightdm): Active" || echo "✗ Session graphique (lightdm): Inactive"
systemctl is-active cron && echo "✓ Cron (scheduler): Actif" || echo "✗ Cron (scheduler): Inactif"
echo ""

echo "=== Moteur de lecture (Chromium kiosk) ==="
pgrep -f chromium > /dev/null && echo "✓ Chromium kiosk: En fonctionnement" || echo "✗ Chromium kiosk: Arrêté"
echo "Playlist à l'écran: $(ls -l /opt/pisignage/media/playlist.json 2>/dev/null | awk '{print $5" octets"}' || echo absente)"
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
echo "Derniers événements de la session graphique (kiosk) :"
journalctl -u lightdm --no-pager -n 5 2>/dev/null || echo "Aucun journal disponible"
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
journalctl -u lightdm --no-pager > $LOGDIR/lightdm-session.log
journalctl -u nginx --no-pager > $LOGDIR/nginx-service.log
journalctl -u php8.4-fpm --no-pager > $LOGDIR/php-service.log

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

- **Session graphique (kiosk)** : `journalctl -u lightdm -f` et `journalctl --user -xe`
- **Serveur web Nginx** : `/var/log/nginx/error.log`
- **Processeur PHP-FPM** : `/var/log/php8.4-fpm.log`
- **Système PiSignage** : `/opt/pisignage/logs/pisignage.log`
- **État du lecteur** : `curl 'http://localhost/api/display.php?action=state'`
- **État du scheduler** : `/opt/pisignage/config/scheduler-state.json`

### Commandes de maintenance courantes

```bash
# Redémarrage des services web
sudo systemctl restart nginx php8.4-fpm

# Redémarrage de la session graphique (relance le kiosk Chromium)
sudo systemctl restart display-manager

# Vérification rapide de l'état des services
sudo systemctl status nginx php8.4-fpm display-manager cron

# Relance du moteur de lecture (tuer Chromium → relance auto par labwc)
sudo pkill -f "/usr/bin/chromium"

# Test de fonctionnement de l'interface web et de la page player
curl -I http://localhost
curl -I http://127.0.0.1/player

# Surveillance en temps réel du moteur de lecture
watch -n 5 'ps aux | grep chromium | grep -v grep'

# Lire l'état rapporté par le player (remplace l'ancienne API VLC port 8080)
curl 'http://localhost/api/display.php?action=state'
```

### Ressources de support

**Canaux de support officiels :**
- **Signalement de problèmes** : https://github.com/elkir0/Pi-Signage/issues
- **Documentation complète** : `/opt/pisignage/docs/`
- **Script de diagnostic** : `/opt/pisignage/scripts/diagnostic.sh`

**Avant de demander de l'aide :**
Exécutez systématiquement le script de diagnostic et incluez les logs générés dans votre demande de support. Cette information permet d'accélérer considérablement la résolution des problèmes.