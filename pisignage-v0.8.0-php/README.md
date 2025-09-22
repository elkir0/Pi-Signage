# PiSignage v0.8.0 - Digital Signage System

## 🚀 Version PHP Optimisée pour Raspberry Pi

### ✅ Caractéristiques

- **Léger** : 35MB vs 750MB (Next.js)
- **Rapide** : Démarrage en 2s vs 30s
- **Stable** : Pas de memory leaks Node.js
- **Simple** : PHP pur, pas de build process

### 📋 Fonctionnalités

- ✅ Screenshot avec 4 méthodes fallback
- ✅ Gestion médias avec upload chunked (500MB)
- ✅ Téléchargement YouTube avec yt-dlp
- ✅ Interface claire et professionnelle
- ✅ Monitoring système temps réel
- ✅ Playlists et programmation

### 🔧 Installation

```bash
# 1. Prérequis
sudo apt update
sudo apt install php8.1-fpm nginx ffmpeg yt-dlp imagemagick

# 2. Clone
git clone https://github.com/elkir0/Pi-Signage.git
cd Pi-Signage/pisignage-v0.8.0-php

# 3. Permissions
chmod 755 -R media/ logs/ screenshots/

# 4. Lancer
php -S localhost:8080 -t public/
```

### 📡 Configuration Nginx

```nginx
server {
    listen 80;
    server_name pisignage.local;
    root /opt/pisignage/pisignage-v0.8.0-php/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    client_max_body_size 500M;
}
```

### 🎯 APIs Disponibles

- `GET /api/screenshot` - Capture d'écran
- `POST /api/media` - Upload média
- `GET /api/media` - Liste médias
- `POST /api/youtube` - Télécharger YouTube
- `GET /api/youtube?action=queue` - Statut téléchargements
- `GET /api/system` - Infos système
- `GET /api/playlist` - Gestion playlists

### 📊 Performance

| Métrique | PHP v0.8.0 | Next.js v2.0 | Amélioration |
|----------|------------|--------------|--------------|
| RAM | 80MB | 400MB | **5x moins** |
| Stockage | 35MB | 750MB | **20x moins** |
| Boot | 2s | 30s | **15x plus rapide** |
| CPU idle | 1-3% | 5-15% | **5x moins** |

### 🔒 Sécurité

- Validation MIME stricte
- Protection CSRF
- Sanitization des uploads
- Logs d'audit

### 📝 Version

**v0.8.0** - Migration PHP complète
- 4 APIs critiques réparées
- Interface professionnelle
- Optimisé pour Raspberry Pi

### 📄 Licence

MIT License - 2024 PiSignage Team