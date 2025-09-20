<<<<<<< HEAD
# Interface Web

Ce dossier contient l'interface web du système PiSignage.

## Structure
- `api/` - API REST pour le contrôle du système
- `assets/` - Ressources statiques (CSS, JS, images)
- `templates/` - Templates HTML
- `index.php` - Page d'accueil principale

## Fonctionnalités
- Interface de gestion des médias
- Contrôle des playlists
- Monitoring du système
- Configuration à distance
=======
# PiSignage Desktop v3.0 - Interface Web

Interface web moderne et simplifiée pour PiSignage Desktop, optimisée pour l'usage tactile et le contrôle depuis mobile.

## 🎯 Caractéristiques

### Interface Modernisée
- **Design responsive** : Mobile-first, optimisé pour écrans tactiles
- **Dark mode** : Basculement automatique jour/nuit avec sauvegarde
- **CSS moderne** : Variables CSS, animations fluides, pas de frameworks lourds
- **Navigation intuitive** : 4 pages principales accessibles en un clic

### Fonctionnalités Simplifiées
- **Dashboard** : Monitoring système temps réel (CPU, RAM, stockage, température)
- **Gestion vidéos** : Upload drag & drop, suppression, téléchargement YouTube
- **Playlist** : Interface drag & drop pour organiser l'ordre de lecture
- **API REST** : Contrôle complet depuis applications mobiles

### Sécurité
- **Authentification basique** : Simple mais efficace pour usage desktop
- **Protection CSRF** : Tokens sur tous les formulaires
- **Headers sécurisés** : Protection XSS, clickjacking, etc.
- **Validation stricte** : Tous les inputs sont validés

## 📁 Structure

```
web/
├── public/              # Fichiers web accessibles
│   ├── index.php       # Dashboard principal
│   ├── videos.php      # Gestion des vidéos
│   ├── playlist.php    # Gestion de la playlist
│   ├── api.php         # Documentation API
│   ├── login.php       # Interface de connexion
│   └── logout.php      # Déconnexion
├── includes/           # Librairies PHP
│   ├── config.php      # Configuration
│   ├── auth.php        # Authentification
│   └── functions.php   # Fonctions utilitaires
├── assets/             # Ressources statiques
│   ├── css/
│   │   └── style.css   # Styles modernes
│   ├── js/
│   │   └── app.js      # JavaScript vanilla
│   └── img/            # Images et icônes
├── api/
│   └── v1/
│       └── endpoints.php # API REST
└── .htaccess           # Configuration Apache
```

## 🚀 Installation

1. **Déployer les fichiers** :
```bash
sudo cp -r /opt/pisignage/pisignage-desktop/web /var/www/pisignage-desktop
sudo chown -R www-data:www-data /var/www/pisignage-desktop
sudo chmod -R 755 /var/www/pisignage-desktop
sudo chmod 640 /var/www/pisignage-desktop/includes/config.php
```

2. **Configurer nginx** :
```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/pisignage-desktop/public;
    index index.php;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location /api {
        try_files $uri $uri/ /api/v1/endpoints.php?$query_string;
    }
    
    location ~ /includes/ {
        deny all;
    }
}
```

3. **Créer les dossiers nécessaires** :
```bash
sudo mkdir -p /opt/videos
sudo mkdir -p /opt/pisignage
sudo chown -R www-data:www-data /opt/videos
sudo chown -R www-data:www-data /opt/pisignage
```

4. **Configuration PHP** :
```ini
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 300
max_input_time = 300
```

## 🔧 Configuration

### Authentification
Modifier dans `/var/www/pisignage-desktop/includes/config.php` :
```php
define('ADMIN_USERNAME', 'admin');
define('ADMIN_PASSWORD', 'votre_mot_de_passe'); // Changez ceci !
```

### Chemins système
```php
define('VIDEO_DIR', '/opt/videos');
define('SCRIPTS_DIR', '/opt/scripts');
define('PLAYLIST_FILE', '/opt/pisignage/playlist.json');
```

### Limites
```php
define('MAX_UPLOAD_SIZE', 200); // MB
define('SESSION_LIFETIME', 3600); // 1 heure
```

## 📱 API REST

Base URL : `http://votre-ip/api/v1/endpoints.php`

### Endpoints principaux

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `?action=system_info` | Infos système |
| GET | `?action=stats` | Stats rapides pour mobile |
| GET | `?action=videos` | Liste des vidéos |
| GET | `?action=playlist` | Playlist actuelle |
| POST | `action=player_control` | Contrôle du player |
| POST | `action=youtube_download` | Téléchargement YouTube |

### Exemple d'usage mobile
```javascript
// Obtenir les stats
const response = await fetch('http://pisignage-ip/api/v1/endpoints.php?action=stats');
const data = await response.json();

// Contrôler le player
await fetch('http://pisignage-ip/api/v1/endpoints.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        action: 'player_control',
        action: 'play'
    })
});
```

## 🎨 Personnalisation

### Thème
Les couleurs sont définies dans les variables CSS :
```css
:root {
    --accent-primary: #3b82f6;
    --success: #10b981;
    --error: #ef4444;
    /* ... */
}
```

### Logo
Remplacer l'icône π dans les headers par votre logo :
```html
<div class="logo-icon">🎬</div> <!-- Votre icône -->
```

## 🔒 Sécurité

### Recommandations production
1. **Changer le mot de passe** par défaut
2. **Configurer HTTPS** avec certificat SSL
3. **Limiter l'accès** par IP si possible
4. **Logs** : Surveiller `/var/log/nginx/` et `/tmp/pisignage-desktop.log`
5. **Firewall** : Fermer les ports non nécessaires

### Headers de sécurité
Automatiquement configurés :
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

## 📊 Monitoring

### Logs applicatifs
```bash
tail -f /tmp/pisignage-desktop.log
```

### Logs web
```bash
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

### Status services
```bash
systemctl status nginx
systemctl status php8.2-fpm
systemctl status pisignage-desktop
```

## 🐛 Dépannage

### Erreur 500
1. Vérifier les permissions : `ls -la /var/www/pisignage-desktop/`
2. Vérifier les logs PHP : `tail -f /var/log/nginx/error.log`
3. Vérifier la config nginx : `nginx -t`

### Upload ne fonctionne pas
1. Vérifier l'espace disque : `df -h /opt/videos`
2. Vérifier les permissions : `ls -la /opt/videos`
3. Vérifier les limites PHP : `php -i | grep upload`

### API inaccessible
1. Vérifier la réécriture d'URL : `.htaccess` ou config nginx
2. Tester directement : `curl http://localhost/api/v1/endpoints.php?action=stats`
3. Vérifier les headers CORS

## 🚀 Évolutions futures

- [ ] Authentification JWT pour l'API
- [ ] Interface PWA pour mobile
- [ ] Streaming en direct
- [ ] Scheduling avancé
- [ ] Multi-écrans
- [ ] Analytics d'affichage

## 📄 Licence

Interface développée pour PiSignage Desktop v3.0
Optimisée pour Raspberry Pi et PC Desktop
>>>>>>> e3d23eed5cb67ecaebb350b4b797596c74b65e7a
