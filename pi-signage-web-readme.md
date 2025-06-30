# 🌐 Interface Web Pi Signage Digital

## Vue d'ensemble

L'interface web Pi Signage offre une gestion complète du système de digital signage directement depuis votre navigateur. Elle permet de télécharger vos propres vidéos YouTube, gérer les fichiers, contrôler VLC et surveiller le système.

## 🚀 Fonctionnalités principales

### 1. **Téléchargement YouTube**
- Téléchargez vos propres vidéos YouTube en collant simplement l'URL
- Choix de la qualité : 480p, 720p ou 1080p
- Téléchargement automatique avec yt-dlp
- Mise à jour automatique de la playlist VLC

### 2. **Gestionnaire de fichiers**
- Interface TinyFileManager intégrée
- Upload/suppression de vidéos
- Visualisation de l'espace disque
- Navigation dans les dossiers

### 3. **Contrôle VLC**
- Statut en temps réel du service VLC
- Redémarrage du service en un clic
- Nombre de vidéos dans la playlist
- Mise à jour automatique de la playlist

### 4. **Monitoring système**
- Utilisation CPU et mémoire
- Température du processeur
- Espace disque disponible
- État des services

## 📋 Installation

### Prérequis
- Module 09 installé via le script principal
- nginx et PHP-FPM configurés
- yt-dlp installé

### Installation automatique
```bash
# Le module 09 installe automatiquement tout
sudo ./09-web-interface.sh

# Ou via le script principal
sudo ./install.sh
```

### Installation manuelle
```bash
# Installer les dépendances
sudo apt update
sudo apt install nginx php8.2-fpm php8.2-cli php8.2-curl php8.2-json

# Installer yt-dlp
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# Déployer les fichiers
sudo ./deploy_web_interface.sh
```

## 🔐 Sécurité

### Authentification
- Login requis pour accéder à l'interface
- Sessions PHP sécurisées
- Mots de passe hachés avec bcrypt

### Accès réseau
- Par défaut accessible sur tout le réseau local
- Pour restreindre l'accès, modifier nginx :
```nginx
# Autoriser seulement le réseau local
allow 192.168.1.0/24;
deny all;
```

### Permissions
- L'utilisateur www-data peut uniquement redémarrer VLC
- Pas d'accès shell depuis l'interface web
- Validation stricte des entrées utilisateur

## 🎯 Utilisation

### Premier accès
1. Ouvrez votre navigateur
2. Accédez à `http://[IP_DU_PI]/`
3. Connectez-vous avec les identifiants configurés
   - Par défaut : admin / [mot de passe défini]

### Télécharger une vidéo
1. Copiez l'URL YouTube de votre vidéo
2. Collez-la dans le champ "URL YouTube"
3. Sélectionnez la qualité souhaitée
4. Cliquez sur "Télécharger"
5. La vidéo sera automatiquement ajoutée à la playlist

### Gérer les vidéos
1. La liste des vidéos s'affiche dans le dashboard
2. Cliquez sur "Supprimer" pour enlever une vidéo
3. Utilisez le gestionnaire de fichiers pour plus d'options

### Contrôler VLC
- Le statut VLC s'affiche en temps réel
- Cliquez sur "Redémarrer VLC" si nécessaire
- Les nouvelles vidéos sont automatiquement prises en compte

## 🔧 Configuration avancée

### Modifier les limites de téléchargement
Éditez `/etc/php/8.2/fpm/pool.d/pi-signage.conf` :
```ini
php_admin_value[upload_max_filesize] = 200M
php_admin_value[post_max_size] = 200M
php_admin_value[max_execution_time] = 600
```

### Activer le HTTPS
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d votre-domaine.com
```

### Personnaliser l'interface
Les fichiers CSS et JS sont dans :
- `/var/www/pi-signage/assets/css/style.css`
- `/var/www/pi-signage/assets/js/main.js`

## 📊 API Endpoints

### GET /api/status.php
Retourne le statut du système en JSON :
```json
{
  "vlc_status": true,
  "disk_usage": 45.2,
  "system_info": {
    "cpu_usage": 25.5,
    "memory_usage": 62.3,
    "temperature": 52.1
  }
}
```

### POST /api/download.php
Déclenche un téléchargement YouTube (nécessite authentification)

## 🚨 Dépannage

### L'interface ne s'affiche pas
```bash
# Vérifier nginx
sudo systemctl status nginx
sudo nginx -t

# Vérifier PHP-FPM
sudo systemctl status php8.2-fpm

# Vérifier les logs
sudo tail -f /var/log/nginx/pi-signage-error.log
```

### Téléchargement YouTube échoue
```bash
# Mettre à jour yt-dlp
sudo yt-dlp -U

# Vérifier les permissions
ls -la /opt/videos

# Tester manuellement
sudo -u www-data yt-dlp --version
```

### VLC ne redémarre pas
```bash
# Vérifier les permissions sudo
sudo cat /etc/sudoers.d/pi-signage-web

# Test manuel
sudo -u www-data sudo systemctl restart vlc-signage.service
```

## 📝 Logs

Les logs sont disponibles dans :
- `/var/log/nginx/pi-signage-*.log` - Logs nginx
- `/var/log/pi-signage/web-*.log` - Logs application
- `/var/log/pi-signage/youtube-download.log` - Logs téléchargements

## 🔄 Mises à jour

### Mise à jour automatique de yt-dlp
Une tâche cron met à jour yt-dlp chaque semaine :
```bash
# Mise à jour manuelle
sudo /opt/scripts/update-ytdlp.sh
```

### Mise à jour de l'interface
```bash
cd /var/www/pi-signage
git pull origin main  # Si utilisé avec Git
sudo chown -R www-data:www-data .
```

## 💡 Conseils d'utilisation

1. **Qualité vidéo** : 720p est recommandé pour un bon équilibre qualité/taille
2. **Espace disque** : Surveillez régulièrement l'espace disponible
3. **Formats** : Préférez MP4 pour une meilleure compatibilité
4. **Noms de fichiers** : Évitez les caractères spéciaux dans les URLs

## 🎨 Personnalisation

### Modifier le thème
Le CSS utilise des variables pour faciliter la personnalisation :
```css
:root {
  --primary-color: #4CAF50;
  --bg-dark: #1a1a1a;
  --bg-light: #2a2a2a;
}
```

### Ajouter des fonctionnalités
L'architecture modulaire permet d'ajouter facilement :
- Planification de playlists
- Téléchargement depuis d'autres plateformes
- Statistiques de lecture
- Notifications par email

## 📄 Licence et mentions légales

- **yt-dlp** : Utilisez uniquement pour télécharger VOS PROPRES vidéos
- **TinyFileManager** : Licence MIT
- **Interface Pi Signage** : Votre licence

---

**Interface Web Pi Signage** - Gérez votre digital signage en toute simplicité ! 🚀