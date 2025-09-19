# 🚀 PiSignage Deployment Guide v3.1.0

## 📋 Table des matières
1. [État actuel](#état-actuel)
2. [Installation rapide](#installation-rapide)
3. [Configuration du serveur web](#configuration-du-serveur-web)
4. [Interface de gestion](#interface-de-gestion)
5. [API REST](#api-rest)
6. [Dépannage](#dépannage)
7. [Maintenance](#maintenance)

---

## 📊 État actuel

✅ **Composants fonctionnels:**
- VLC en boucle avec accélération matérielle (~8% CPU)
- Vidéo Big Buck Bunny 720p en lecture continue
- Autostart configuré et testé
- Structure modulaire créée dans `/opt/pisignage/`

🎯 **Prochaines étapes:**
- Déploiement du serveur web
- Interface de gestion
- API de contrôle
- Système de playlist

---

## 🚀 Installation rapide

### Prérequis
- Raspberry Pi 4 avec Raspberry Pi OS Desktop
- Connexion SSH active
- Accès root (sudo)
- VLC installé et fonctionnel

### Commandes d'installation

Connectez-vous au Raspberry Pi:
```bash
ssh pi@192.168.1.103
# Password: palmer00
```

Exécutez les commandes suivantes:

```bash
# 1. Installation des dépendances
sudo apt-get update
sudo apt-get install -y nginx php-fpm php-json php-curl php-mbstring jq curl wget

# 2. Création de la structure
sudo mkdir -p /var/www/pisignage/{api,assets,templates,uploads}
sudo mkdir -p /opt/pisignage/{media,logs,config,scripts}
sudo chmod 755 /opt/pisignage
sudo chown -R www-data:www-data /var/www/pisignage
sudo chmod 775 /var/www/pisignage/uploads

# 3. Création du script de contrôle VLC
sudo tee /opt/pisignage/scripts/vlc-control.sh > /dev/null << 'EOF'
#!/bin/bash

ACTION=$1
VIDEO_PATH=$2

case $ACTION in
    play)
        pkill vlc 2>/dev/null
        DISPLAY=:0 cvlc --fullscreen --loop --no-video-title-show "${VIDEO_PATH:-/home/pi/Big_Buck_Bunny_720_10s_30MB.mp4}" &
        echo "Video started: ${VIDEO_PATH}"
        ;;
    stop)
        pkill vlc
        echo "Video stopped"
        ;;
    status)
        if pgrep vlc > /dev/null; then
            echo "VLC is running"
            ps aux | grep vlc | grep -v grep
        else
            echo "VLC is not running"
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        $0 play "$VIDEO_PATH"
        ;;
    *)
        echo "Usage: $0 {play|stop|status|restart} [video_path]"
        exit 1
        ;;
esac
EOF

sudo chmod +x /opt/pisignage/scripts/vlc-control.sh
sudo chown pi:pi /opt/pisignage/scripts/vlc-control.sh

# 4. Configuration nginx
sudo tee /etc/nginx/sites-available/pisignage > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/pisignage;
    index index.php index.html;

    client_max_body_size 500M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location /media {
        alias /opt/pisignage/media;
        autoindex on;
    }

    location /api {
        try_files $uri $uri/ /api/index.php?$query_string;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 5. Permissions pour www-data
echo "www-data ALL=(pi) NOPASSWD: /opt/pisignage/scripts/vlc-control.sh" | sudo tee /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/pkill vlc" | sudo tee -a /etc/sudoers.d/pisignage
echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/cvlc" | sudo tee -a /etc/sudoers.d/pisignage
sudo chmod 440 /etc/sudoers.d/pisignage

# 6. Copier la vidéo dans le dossier media
cp /home/pi/Big_Buck_Bunny_720_10s_30MB.mp4 /opt/pisignage/media/ 2>/dev/null || true

# 7. Redémarrer les services
sudo systemctl restart nginx
sudo systemctl restart php*-fpm
sudo systemctl enable nginx
sudo systemctl enable php*-fpm

# 8. Test
/opt/pisignage/scripts/vlc-control.sh status
```

---

## 🌐 Configuration du serveur web

### Déploiement de l'interface

Téléchargez l'interface web depuis votre machine locale:

```bash
# Sur votre machine locale
scp /opt/pisignage/web/index-complete.php pi@192.168.1.103:/tmp/index.php

# Sur le Raspberry Pi
sudo mv /tmp/index.php /var/www/pisignage/index.php
sudo chown www-data:www-data /var/www/pisignage/index.php
```

### Test de l'interface

Accédez à l'interface web:
```
http://192.168.1.103/
```

---

## 💻 Interface de gestion

### Fonctionnalités disponibles

#### 1. Tableau de bord
- État du lecteur (Playing/Stopped)
- Température CPU
- Utilisation mémoire
- Utilisation disque

#### 2. Contrôle du lecteur
- ▶️ **Play Default** : Lance la vidéo par défaut
- ⏹️ **Stop** : Arrête la lecture
- 🔄 **Restart** : Redémarre le lecteur
- 🔄 **Refresh** : Actualise le statut

#### 3. Gestion des médias
- Upload par drag & drop ou clic
- Support: MP4, AVI, MKV, MOV, WEBM
- Taille max: 500MB
- Liste des médias avec actions Play/Delete

#### 4. Monitoring temps réel
- Auto-refresh toutes les 10 secondes
- Indicateurs visuels de statut
- Statistiques système

---

## 🔌 API REST

### Endpoints disponibles

#### GET /?action=status
Retourne l'état du système
```json
{
  "success": true,
  "data": {
    "hostname": "raspberrypi",
    "uptime": "up 2 days",
    "cpu_temp": 45.2,
    "mem_percent": 35,
    "disk_percent": 42,
    "vlc_running": true
  }
}
```

#### POST /?action=play
Lance une vidéo
```bash
curl -X POST http://192.168.1.103/?action=play \
  -d "video=myvideo.mp4"
```

#### POST /?action=stop
Arrête la lecture
```bash
curl -X POST http://192.168.1.103/?action=stop
```

#### GET /?action=list
Liste les médias disponibles
```bash
curl http://192.168.1.103/?action=list
```

#### POST /?action=upload
Upload un fichier vidéo
```bash
curl -X POST http://192.168.1.103/?action=upload \
  -F "video=@/path/to/video.mp4"
```

#### POST /?action=delete
Supprime un média
```bash
curl -X POST http://192.168.1.103/?action=delete \
  -d "video=unwanted.mp4"
```

---

## 🔧 Dépannage

### Problèmes courants

#### 1. Page blanche ou erreur 500
```bash
# Vérifier les logs PHP
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/php*/error.log

# Vérifier les permissions
sudo chown -R www-data:www-data /var/www/pisignage
sudo chmod -R 755 /var/www/pisignage
```

#### 2. VLC ne démarre pas depuis l'interface
```bash
# Vérifier les permissions sudo
sudo cat /etc/sudoers.d/pisignage

# Test manuel du script
sudo -u www-data /opt/pisignage/scripts/vlc-control.sh status
```

#### 3. Upload ne fonctionne pas
```bash
# Vérifier la taille max dans nginx
sudo nano /etc/nginx/sites-available/pisignage
# Ajouter: client_max_body_size 500M;

# Vérifier PHP
sudo nano /etc/php/*/fpm/php.ini
# upload_max_filesize = 500M
# post_max_size = 500M

sudo systemctl restart nginx php*-fpm
```

#### 4. Vidéo ne se lance pas
```bash
# Vérifier DISPLAY
echo $DISPLAY  # Doit afficher :0

# Test manuel
DISPLAY=:0 cvlc --fullscreen /opt/pisignage/media/test.mp4
```

---

## 🛠️ Maintenance

### Commandes utiles

#### Surveillance des logs
```bash
# Logs système
sudo journalctl -f

# Logs nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Logs PHP
sudo tail -f /var/log/php*/error.log
```

#### Nettoyage
```bash
# Nettoyer les vieux logs
sudo truncate -s 0 /var/log/nginx/*.log
sudo truncate -s 0 /opt/pisignage/logs/*.log

# Nettoyer le cache
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

#### Backup
```bash
# Sauvegarder la configuration
tar -czf pisignage-backup-$(date +%Y%m%d).tar.gz \
  /opt/pisignage/config \
  /var/www/pisignage \
  /etc/nginx/sites-available/pisignage

# Sauvegarder les médias
tar -czf pisignage-media-$(date +%Y%m%d).tar.gz \
  /opt/pisignage/media
```

#### Monitoring
```bash
# CPU et mémoire
htop

# Espace disque
df -h

# Processus VLC
ps aux | grep vlc

# Connexions réseau
sudo netstat -tlnp
```

---

## 📝 Notes importantes

### Sécurité
- Changez le mot de passe par défaut du Pi
- Configurez un firewall si exposé sur internet
- Utilisez HTTPS en production (Let's Encrypt)
- Limitez les accès SSH

### Performance
- GPU mem configuré à 128MB
- Utilisation de l'accélération matérielle VLC
- Cache nginx pour les assets statiques
- PHP-FPM optimisé pour ARM

### Compatibilité
- Testé sur Raspberry Pi 4
- Raspberry Pi OS Desktop (Bookworm)
- PHP 7.4+ / 8.0+
- Nginx 1.18+

---

## 🎯 Prochaines améliorations

- [ ] Système de playlist avec scheduling
- [ ] Support multi-zones d'affichage
- [ ] Authentification utilisateur
- [ ] Dashboard avancé avec graphiques
- [ ] Support HDMI-CEC pour contrôle TV
- [ ] Synchronisation multi-Pi
- [ ] Application mobile de contrôle
- [ ] Intégration calendrier/RSS
- [ ] Support streaming RTSP/HLS

---

## 📞 Support

- **GitHub**: https://github.com/elkir0/Pi-Signage
- **Documentation**: `/opt/pisignage/docs/`
- **Logs**: `/opt/pisignage/logs/`

---

*Document créé le 19/09/2025 - PiSignage v3.1.0*