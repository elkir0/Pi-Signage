# Pi Signage - Interface Web v2.4.0

Interface web moderne de gestion pour Pi Signage Digital avec support des modes VLC et Chromium Kiosk.

## 🎯 Fonctionnalités

- **Dashboard temps réel** : Monitoring CPU, RAM, température, espace disque avec logo
- **Gestion des vidéos** : Upload, suppression, téléchargement YouTube amélioré
- **Gestion de playlist** : Page dédiée pour organiser l'ordre de lecture
- **Téléchargement YouTube** : Verbose persistant, format MP4 forcé
- **API de contrôle** : player.php pour contrôler play/pause/stop/next
- **Paramètres système** : Contrôle des services, mise à jour playlist
- **Support multi-modes** : Interface adaptative VLC/Chromium
- **Sécurité renforcée** : SHA-512, CSRF, headers de sécurité

## 📁 Structure

```
web-interface/
├── public/              # Fichiers accessibles publiquement
│   ├── index.php       # Page de connexion avec logo
│   ├── dashboard.php   # Tableau de bord principal
│   ├── videos.php      # Gestion des vidéos
│   ├── playlist.php    # Gestion de la playlist
│   ├── settings.php    # Paramètres système
│   └── logout.php      # Déconnexion
├── includes/           # Fichiers PHP inclus (non accessibles directement)
│   ├── config.php      # Configuration (généré à l'installation)
│   ├── config.template.php # Template de configuration
│   ├── functions.php   # Fonctions utilitaires
│   ├── auth.php        # Gestion de l'authentification SHA-512
│   └── security.php    # Fonctions de sécurité (CSRF, headers)
├── api/                # Points d'accès API REST
│   ├── status.php      # Statut du système
│   ├── control.php     # Contrôle des services
│   ├── player.php      # Contrôle du player (play/pause/stop/next)
│   ├── youtube.php     # Téléchargement YouTube amélioré
│   └── youtube_progress.php # Stub pour éviter erreurs 400
├── assets/             # Ressources statiques
│   ├── css/           # Styles CSS
│   ├── js/            # Scripts JavaScript
│   └── images/        # Images et icônes
└── templates/          # Templates HTML réutilisables
    ├── navigation.php  # Navigation avec logo
    └── header-meta.php # Meta tags pour favicon et logo
```

## 🚀 Installation

L'interface web est automatiquement déployée par le script d'installation Pi Signage (`09-web-interface-v2.sh`).

### Processus automatique :
1. Clone ce répertoire depuis GitHub
2. Configure les permissions appropriées (755 pour répertoires, 640 pour config)
3. Génère le fichier de configuration avec les mots de passe SHA-512
4. Configure nginx et PHP-FPM avec pool dédié
5. Crée la structure des assets si manquante
6. Configure les permissions sudo pour www-data

### Installation manuelle :
```bash
# Cloner le dépôt
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/raspberry-pi-installer/scripts

# Installer uniquement l'interface web
sudo ./09-web-interface-v2.sh
```

## 🔐 Sécurité

### Authentification
- **Méthode** : SHA-512 avec salt (harmonisé avec bash)
- **Session** : Cookies sécurisés HttpOnly
- **Timeout** : Session de 30 minutes

### Protection
- ✅ **CSRF** : Tokens sur tous les formulaires
- ✅ **Headers** : X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- ✅ **Validation** : Entrées strictement validées
- ✅ **Permissions** : 755 répertoires, 640 fichiers sensibles
- ✅ **Sudo** : Permissions limitées pour www-data

## ⚙️ Configuration

Le fichier `includes/config.php` est généré automatiquement lors de l'installation :

```php
// Chemins système
define('VIDEO_DIR', '/opt/videos');
define('SCRIPTS_DIR', '/opt/scripts');

// Authentification (SHA-512)
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD_HASH', 'salt:hash');

// Mode d'affichage
define('DISPLAY_MODE', 'vlc'); // ou 'chromium'

// Logo et branding
define('LOGO_PATH', 'assets/images/logo.png');
define('APP_NAME', 'Pi Signage');
define('APP_VERSION', '2.4.0');

// Services
define('GLANCES_URL', 'http://localhost:61208');
```

## 📋 Pages principales

### Dashboard (`dashboard.php`)
- État système en temps réel
- Monitoring CPU, RAM, température
- Espace disque et nombre de vidéos
- Contrôles rapides des services

### Gestion vidéos (`videos.php`)
- Upload de vidéos (drag & drop supporté)
- Liste avec taille et date
- Suppression avec confirmation
- Téléchargement YouTube amélioré avec verbose persistant
- Mise à jour automatique de la playlist après upload
- Barre de progression espace disque

### Gestion playlist (`playlist.php`)
- Sélection des vidéos à diffuser
- Organisation de l'ordre de lecture
- Sauvegarde automatique
- Synchronisation avec le player

### Paramètres (`settings.php`)
- Informations système détaillées
- État et contrôle des services
- Redémarrage système
- Mise à jour playlist
- Téléchargement des logs
- Accès aux interfaces (Glances, Player HTML5)

## 🛠️ API Endpoints

### `/api/status.php`
```json
{
  "success": true,
  "data": {
    "cpu": {"load": [0.5, 0.4, 0.3]},
    "memory": {"used": 512000000, "total": 1024000000},
    "disk": {"used": 10737418240, "free": 21474836480},
    "services": {"vlc-signage": true, "nginx": true}
  }
}
```

### `/api/control.php`
- Actions : start, stop, restart, status
- Services : vlc-signage, chromium-kiosk, nginx, glances

### `/api/player.php`
- Actions : play, pause, stop, next, previous, reload, update_playlist
- Support VLC (via HTTP) et Chromium (via WebSocket)
- Retourne `{success: bool, message?: string}`

### `/api/youtube.php`
- Téléchargement avec format MP4 forcé
- Verbose détaillé dans la réponse
- Mise à jour automatique de la playlist
- Retourne `{success: bool, output: string, playlist_updated?: bool}`

## 💻 Développement

### Test local
```bash
# Serveur PHP intégré
php -S localhost:8000 -t public/

# Avec variables d'environnement
ADMIN_USERNAME=admin ADMIN_PASSWORD_HASH=test:hash php -S localhost:8000 -t public/
```

### Structure des assets
```
assets/
├── css/
│   ├── style.css      # Styles principaux
│   └── dashboard.css  # Styles spécifiques
├── js/
│   └── main.js        # JavaScript principal
└── images/
    └── logo.png       # Logo Pi Signage
```

## 📦 Dépendances

### PHP
- PHP 8.2+ (JSON intégré)
- Extensions : curl, mbstring, xml, zip
- PHP-FPM avec pool dédié

### Système
- nginx (serveur web)
- yt-dlp (téléchargement YouTube)
- ffmpeg (traitement vidéo)
- sudo (contrôle services)

### JavaScript
- Vanilla JS (pas de framework)
- Fetch API pour les requêtes AJAX
- WebSocket pour le player Chromium

## 🔄 Mises à jour

Un script de mise à jour est disponible :
```bash
sudo /opt/scripts/util-update-web-interface.sh
```

Autres scripts utilitaires :
```bash
# Changer le mot de passe web
sudo /opt/scripts/util-change-web-password.sh

# Configurer l'audio
sudo /opt/scripts/util-configure-audio.sh

# Tester la playlist
sudo /opt/scripts/util-test-playlist.sh
```

## 🐛 Dépannage

### Erreur 500
- Vérifier les permissions : `ls -la /var/www/pi-signage/`
- Logs PHP : `tail -f /var/log/pi-signage/php-error.log`
- Logs nginx : `tail -f /var/log/nginx/pi-signage-error.log`

### Authentification échoue
- Vérifier le format du hash : `grep ADMIN_PASSWORD_HASH /var/www/pi-signage/includes/config.php`
- Format attendu : `salt:hash` (SHA-512)

### Upload ne fonctionne pas
- Vérifier l'espace disque : `df -h /opt/videos`
- Permissions : `ls -la /opt/videos`
- Taille max upload : 150MB (configurable dans PHP-FPM)
