# PiSignage Interface Complète v3.1.0

## 🎬 Vue d'ensemble

Cette interface web complète pour PiSignage offre toutes les fonctionnalités d'un système d'affichage numérique professionnel. Elle a été conçue pour être intuitive, moderne et complète.

## ✨ Fonctionnalités principales

### 📊 Dashboard
- **Statistiques en temps réel** : CPU, mémoire, disque, température
- **Statut du lecteur** : VLC en cours d'exécution ou arrêté
- **Contrôles rapides** : lecture, pause, arrêt, redémarrage
- **Capture d'écran** : aperçu en temps réel de l'affichage
- **Actualisation automatique** : toutes les 30 secondes

### 🎵 Gestion des médias
- **Upload drag & drop** : glissez-déposez vos fichiers
- **Formats supportés** : MP4, AVI, MKV, MOV, WEBM, JPG, PNG, GIF
- **Prévisualisation** : aperçu des vidéos et images
- **Métadonnées** : taille, durée, date de modification
- **Actions rapides** : lecture, ajout à playlist, suppression
- **Optimisation automatique** : recompression si nécessaire

### 📑 Éditeur de playlists
- **Interface intuitive** : éditeur visuel avec drag & drop
- **Gestion complète** : création, édition, suppression
- **Paramètres avancés** : boucle, aléatoire, transitions
- **Durées personnalisables** : contrôle précis du timing
- **Import/Export** : sauvegarde et partage des playlists
- **Activation instantanée** : changement de playlist en un clic

### 📺 Téléchargement YouTube
- **Téléchargement direct** : depuis l'interface web
- **Choix de qualité** : 360p, 480p, 720p, meilleure qualité
- **Aperçu vidéo** : informations détaillées avant téléchargement
- **File d'attente** : gestion des téléchargements multiples
- **Progression en temps réel** : suivi du téléchargement
- **Optimisation automatique** : conversion au format optimal

### ⏰ Programmation horaire
- **Planificateur avancé** : programmation par jour et heure
- **Modèles prédéfinis** : horaires bureaux, week-end, 24/7
- **Activation automatique** : changement de playlist selon l'heure
- **Gestion des exceptions** : jours fériés, événements spéciaux
- **Interface calendrier** : visualisation des programmations

### 🖥️ Configuration d'affichage
- **Résolutions multiples** : Full HD, HD, personnalisée
- **Orientations** : paysage, portrait, inversé
- **Volume système** : contrôle du niveau sonore
- **Transitions animées** : 8 types d'effets disponibles
- **Multi-zones** : division de l'écran en plusieurs zones
- **Prévisualisation** : test des paramètres en temps réel

### ⚙️ Configuration système
- **Paramètres généraux** : nom d'affichage, démarrage automatique
- **Configuration réseau** : WiFi, IP, scan des réseaux
- **Maintenance** : sauvegarde, restauration, logs
- **Contrôle système** : redémarrage, extinction à distance
- **Monitoring** : surveillance des performances

## 🗂️ Structure des fichiers

```
/opt/pisignage/
├── web/
│   ├── index-complete.php          # Interface principale
│   ├── api/
│   │   ├── playlist.php            # API gestion playlists
│   │   └── youtube.php             # API téléchargement YouTube
│   └── assets/
│       └── screenshots/            # Captures d'écran
├── scripts/
│   ├── screenshot.sh               # Script capture d'écran
│   ├── youtube-dl.sh              # Script téléchargement YouTube
│   └── download-test-videos.sh    # Script vidéos de test
├── config/
│   └── playlists.json             # Configuration playlists
├── media/                         # Dossier des médias
└── logs/                          # Fichiers de logs
```

## 🚀 Installation rapide

### 1. Installation automatique
```bash
# Exécuter le script d'installation complet
cd /opt/pisignage
sudo ./install-complete-system.sh
```

### 2. Installation manuelle des dépendances
```bash
# Mettre à jour le système
sudo apt-get update

# Installer les dépendances
sudo apt-get install -y curl wget ffmpeg php php-cli php-curl php-json php-mbstring scrot apache2 libapache2-mod-php

# Installer yt-dlp
sudo pip3 install yt-dlp
# OU
sudo wget -O /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
sudo chmod +x /usr/local/bin/yt-dlp

# Configurer Apache
sudo a2enmod php*
sudo a2enmod rewrite
sudo systemctl restart apache2
```

### 3. Configuration des permissions
```bash
# Permissions pour les scripts
chmod +x /opt/pisignage/scripts/*.sh

# Permissions web
sudo chown -R www-data:www-data /opt/pisignage/web
sudo chmod -R 755 /opt/pisignage/web

# Permissions médias
chmod 755 /opt/pisignage/media
```

## 🌐 Accès à l'interface

### URL d'accès
- **Local** : `http://localhost/pisignage/index-complete.php`
- **Réseau** : `http://[IP_DU_PI]/pisignage/index-complete.php`
- **Exemple** : `http://192.168.1.100/pisignage/index-complete.php`

### Configuration Apache (optionnelle)
Créer un virtual host pour un accès plus simple :

```apache
# /etc/apache2/sites-available/pisignage.conf
<VirtualHost *:80>
    DocumentRoot /opt/pisignage/web
    ServerName pisignage.local
    
    <Directory /opt/pisignage/web>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

## 📱 Interface utilisateur

### Navigation par onglets
L'interface est organisée en 7 onglets principaux :

1. **📊 Dashboard** - Vue d'ensemble et contrôles
2. **🎵 Médias** - Gestion des fichiers
3. **📑 Playlists** - Création et édition
4. **📺 YouTube** - Téléchargement de vidéos
5. **⏰ Programmation** - Planification horaire
6. **🖥️ Affichage** - Configuration de l'écran
7. **⚙️ Configuration** - Paramètres système

### Design responsive
- **Desktop** : Interface complète avec toutes les fonctionnalités
- **Tablet** : Adaptation automatique de la mise en page
- **Mobile** : Version optimisée pour les écrans tactiles

## 🎯 Guide d'utilisation

### Premier démarrage

1. **Accéder à l'interface** via votre navigateur
2. **Télécharger des vidéos de test** depuis l'onglet Médias
3. **Créer votre première playlist** dans l'onglet Playlists
4. **Activer la playlist** pour commencer la diffusion
5. **Prendre une capture d'écran** pour vérifier l'affichage

### Téléchargement de médias

#### Upload de fichiers locaux
1. Aller dans l'onglet **Médias**
2. Glisser-déposer vos fichiers dans la zone d'upload
3. Attendre la fin du transfert
4. Vérifier que les fichiers apparaissent dans la liste

#### Téléchargement YouTube
1. Aller dans l'onglet **YouTube**
2. Coller l'URL de la vidéo
3. Choisir la qualité (720p recommandé)
4. Cliquer sur **Télécharger**
5. Suivre la progression dans la file d'attente

### Création de playlists

1. Aller dans l'onglet **Playlists**
2. Cliquer sur **Nouvelle playlist**
3. Donner un nom et une description
4. Glisser des médias depuis la bibliothèque
5. Ajuster les durées et transitions
6. **Sauvegarder** la playlist

### Programmation horaire

1. Aller dans l'onglet **Programmation**
2. Sélectionner une playlist
3. Choisir les jours de la semaine
4. Définir les heures de début et fin
5. Cliquer sur **Programmer**

## 🔧 Scripts utilitaires

### Capture d'écran
```bash
# Capture manuelle
/opt/pisignage/scripts/screenshot.sh

# Capture avec nom personnalisé
/opt/pisignage/scripts/screenshot.sh /chemin/ma-capture.png
```

### Téléchargement YouTube
```bash
# Téléchargement simple
/opt/pisignage/scripts/youtube-dl.sh "https://www.youtube.com/watch?v=VIDEO_ID"

# Avec qualité spécifique
/opt/pisignage/scripts/youtube-dl.sh "URL" 480p

# Avec nom personnalisé
/opt/pisignage/scripts/youtube-dl.sh "URL" 720p "mon-video"
```

### Vidéos de test
```bash
# Télécharger des vidéos de démonstration
/opt/pisignage/scripts/download-test-videos.sh
```

## 🔍 APIs disponibles

### API Playlists (`/api/playlist.php`)

#### Lister les playlists
```http
GET /api/playlist.php?action=list
```

#### Créer une playlist
```http
POST /api/playlist.php
Content-Type: application/json

{
    "name": "Ma playlist",
    "description": "Description",
    "items": [
        {
            "media_id": "video1.mp4",
            "duration": 10
        }
    ],
    "settings": {
        "loop": true,
        "shuffle": false,
        "transition": "fade"
    }
}
```

#### Activer une playlist
```http
PUT /api/playlist.php?id=PLAYLIST_ID&action=activate
```

### API YouTube (`/api/youtube.php`)

#### Obtenir les informations d'une vidéo
```http
GET /api/youtube.php?action=info&url=YOUTUBE_URL
```

#### Démarrer un téléchargement
```http
POST /api/youtube.php?action=download
Content-Type: application/json

{
    "url": "https://www.youtube.com/watch?v=VIDEO_ID",
    "quality": "720p",
    "name": "nom-personnalise"
}
```

#### Suivre les téléchargements
```http
GET /api/youtube.php?action=status
```

## 🎨 Personnalisation

### Thèmes et couleurs
L'interface utilise des variables CSS pour faciliter la personnalisation :

```css
:root {
    --primary: #6366f1;        /* Couleur principale */
    --success: #10b981;        /* Couleur de succès */
    --danger: #ef4444;         /* Couleur d'erreur */
    --warning: #f59e0b;        /* Couleur d'avertissement */
    --bg: #f8fafc;             /* Arrière-plan */
    --card-bg: #ffffff;        /* Arrière-plan des cartes */
}
```

### Mode sombre
Le mode sombre s'active automatiquement selon les préférences système :

```css
@media (prefers-color-scheme: dark) {
    :root {
        --bg: #0f172a;
        --card-bg: #1e293b;
        --text: #f1f5f9;
    }
}
```

## 🛠️ Dépannage

### Problèmes courants

#### L'interface ne s'affiche pas
1. Vérifier qu'Apache est démarré : `sudo systemctl status apache2`
2. Vérifier les permissions : `ls -la /opt/pisignage/web/`
3. Consulter les logs Apache : `sudo tail -f /var/log/apache2/error.log`

#### Les vidéos ne se téléchargent pas
1. Vérifier que yt-dlp est installé : `yt-dlp --version`
2. Tester manuellement : `yt-dlp "URL_YOUTUBE"`
3. Vérifier les permissions : `chmod +x /opt/pisignage/scripts/youtube-dl.sh`

#### La capture d'écran ne fonctionne pas
1. Installer scrot : `sudo apt-get install scrot`
2. Tester manuellement : `scrot /tmp/test.png`
3. Vérifier les permissions du script

#### Les playlists ne se sauvegardent pas
1. Vérifier les permissions : `chmod 755 /opt/pisignage/config/`
2. Vérifier l'espace disque : `df -h`
3. Consulter les logs : `tail -f /opt/pisignage/logs/playlist.log`

### Logs de débogage
```bash
# Logs système
tail -f /opt/pisignage/logs/installation.log

# Logs playlists
tail -f /opt/pisignage/logs/playlist.log

# Logs YouTube
tail -f /opt/pisignage/logs/youtube.log

# Logs téléchargement vidéos
tail -f /opt/pisignage/logs/video-download.log

# Logs Apache
sudo tail -f /var/log/apache2/error.log
```

## 🔒 Sécurité

### Recommandations
1. **Changer les mots de passe par défaut** du système
2. **Configurer un firewall** pour limiter l'accès
3. **Utiliser HTTPS** en production
4. **Mettre à jour régulièrement** le système
5. **Sauvegarder** la configuration

### Configuration HTTPS (optionnelle)
```bash
# Installer Let's Encrypt
sudo apt-get install certbot python3-certbot-apache

# Obtenir un certificat
sudo certbot --apache -d votre-domaine.com

# Renouvellement automatique
sudo crontab -e
# Ajouter : 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📈 Performance

### Optimisations recommandées
1. **Utiliser un SSD** pour un accès plus rapide aux médias
2. **Augmenter la RAM** pour les vidéos haute résolution
3. **Configurer le cache PHP** avec OPcache
4. **Optimiser les vidéos** avant upload (H.264, résolution adaptée)
5. **Nettoyer régulièrement** les fichiers temporaires

### Configuration PHP optimale
```php
; /etc/php/*/apache2/php.ini
memory_limit = 512M
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
```

## 📞 Support

### Documentation
- **README principal** : `/opt/pisignage/README.md`
- **Logs d'installation** : `/opt/pisignage/logs/installation.log`
- **Configuration** : `/opt/pisignage/config/`

### Ressources utiles
- **Repository GitHub** : Documentation complète
- **Wiki** : Guides détaillés et tutoriels
- **Issues** : Rapporter des bugs ou demander de l'aide

## 🎉 Conclusion

Cette interface complète transforme votre Raspberry Pi en un système d'affichage numérique professionnel avec toutes les fonctionnalités modernes attendues. Elle est conçue pour être simple à utiliser tout en offrant des capacités avancées pour les utilisateurs expérimentés.

**Bon affichage numérique ! 🚀**