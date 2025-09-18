# Installation PiSignage Desktop v3.0

## 🚀 Installation rapide

1. **Exécuter le script de déploiement** :
```bash
cd /opt/pisignage/pisignage-desktop/web
sudo ./deploy.sh
```

2. **Accéder à l'interface** :
   - Ouvrir http://IP_DE_VOTRE_MACHINE dans un navigateur
   - Se connecter avec : `admin` / `pisignage`

## 📋 Installation manuelle

### Prérequis
- Ubuntu/Debian avec nginx et PHP 8.2+
- Accès root (sudo)

### Étapes

1. **Installer les dépendances** :
```bash
sudo apt update
sudo apt install nginx php8.2-fpm php8.2-curl php8.2-json php8.2-mbstring
```

2. **Copier les fichiers** :
```bash
sudo cp -r /opt/pisignage/pisignage-desktop/web /var/www/pisignage-desktop
sudo chown -R www-data:www-data /var/www/pisignage-desktop
sudo chmod -R 755 /var/www/pisignage-desktop
```

3. **Créer les dossiers** :
```bash
sudo mkdir -p /opt/videos /opt/pisignage
sudo chown -R www-data:www-data /opt/videos /opt/pisignage
```

4. **Configurer nginx** :
```bash
sudo cp /var/www/pisignage-desktop/config/nginx-site.conf /etc/nginx/sites-available/pisignage-desktop
sudo ln -s /etc/nginx/sites-available/pisignage-desktop /etc/nginx/sites-enabled/
sudo unlink /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

5. **Configurer PHP** :
```bash
# Éditer /etc/php/8.2/fpm/php.ini
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 300
sudo systemctl restart php8.2-fpm
```

## 🔧 Configuration

### Changer le mot de passe
Éditer `/var/www/pisignage-desktop/includes/config.php` :
```php
define('ADMIN_PASSWORD', 'votre_nouveau_mot_de_passe');
```

### Personnaliser les chemins
```php
define('VIDEO_DIR', '/opt/videos');
define('PLAYLIST_FILE', '/opt/pisignage/playlist.json');
```

## 🌐 Accès

- **Interface web** : http://votre-ip/
- **API REST** : http://votre-ip/api/v1/endpoints.php
- **Documentation API** : http://votre-ip/api.php

## 📱 Contrôle mobile

L'API REST permet le contrôle depuis une application mobile :

```bash
# Obtenir les stats
curl http://votre-ip/api/v1/endpoints.php?action=stats

# Contrôler le player
curl -X POST http://votre-ip/api/v1/endpoints.php \
  -H "Content-Type: application/json" \
  -d '{"action":"player_control","action":"play"}'
```

## 🔒 Sécurité production

1. **HTTPS** : Configurer SSL/TLS
2. **Firewall** : Limiter l'accès aux ports 80/443
3. **Mot de passe** : Utiliser un mot de passe fort
4. **Mise à jour** : Maintenir le système à jour

## 🐛 Dépannage

### Interface inaccessible
```bash
sudo systemctl status nginx php8.2-fpm
sudo nginx -t
tail -f /var/log/nginx/error.log
```

### Upload ne fonctionne pas
```bash
ls -la /opt/videos
df -h /opt/videos
php -i | grep upload_max_filesize
```

### API indisponible
```bash
curl -I http://localhost/api/v1/endpoints.php?action=stats
tail -f /var/log/nginx/access.log
```

## 📊 Logs

- **Application** : `/tmp/pisignage-desktop.log`
- **Nginx** : `/var/log/nginx/pisignage-*.log`
- **PHP** : `/var/log/nginx/error.log`

## 🆘 Support

- Vérifier les logs
- Tester avec curl
- Vérifier les permissions
- Redémarrer les services