# 📁 Structure du Projet Pi Signage Web Interface

## Organisation des Fichiers pour GitHub

Voici comment organiser les fichiers de l'interface web pour votre repository GitHub :

```
pi-signage-web/
│
├── README.md                    # Documentation principale (créé ci-dessus)
├── LICENSE                      # Licence MIT
├── .gitignore                   # Fichiers à ignorer
│
├── src/                         # Code source de l'interface web
│   ├── index.php               # Page de connexion
│   ├── dashboard.php           # Dashboard principal  
│   ├── download.php            # Téléchargement YouTube
│   ├── logs.php                # Visualisation des logs
│   ├── logout.php              # Déconnexion
│   │
│   ├── includes/               # Fichiers PHP inclus
│   │   ├── config.php          # Configuration
│   │   ├── functions.php       # Fonctions utilitaires
│   │   └── session.php         # Gestion des sessions
│   │
│   ├── assets/                 # Ressources statiques
│   │   ├── css/
│   │   │   └── style.css       # Styles CSS
│   │   ├── js/
│   │   │   └── main.js         # JavaScript principal
│   │   └── img/
│   │       └── favicon.png     # Favicon (à créer)
│   │
│   ├── api/                    # Endpoints API
│   │   ├── status.php          # API de statut
│   │   ├── download.php        # API téléchargement (à créer)
│   │   └── upload.php          # API upload (à créer)
│   │
│   └── temp/                   # Dossier temporaire
│       └── .gitkeep            # Pour garder le dossier dans Git
│
├── install/                     # Scripts d'installation
│   ├── install.sh              # Script d'installation automatique
│   ├── nginx.conf              # Configuration nginx exemple
│   └── php-fpm.conf            # Configuration PHP-FPM exemple
│
├── docs/                        # Documentation supplémentaire
│   ├── INSTALL.md              # Guide d'installation détaillé
│   ├── API.md                  # Documentation API
│   ├── SECURITY.md             # Guide de sécurité
│   └── screenshots/            # Captures d'écran
│       ├── dashboard.png
│       ├── download.png
│       └── logs.png
│
└── examples/                    # Exemples de configuration
    ├── config.conf.example      # Exemple de configuration
    └── .env.example            # Variables d'environnement

```

## 📝 Fichiers à Créer

### 1. `.gitignore`
```gitignore
# Logs
*.log
logs/

# Fichiers temporaires
temp/*
!temp/.gitkeep

# Configuration locale
config.local.php
.env

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Backup
*.backup
*.bak

# Sessions PHP
sessions/
```

### 2. `LICENSE` (MIT)
```
MIT License

Copyright (c) 2024 [Votre Nom]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 3. `install/install.sh`
```bash
#!/bin/bash

# Script d'installation automatique Pi Signage Web Interface
# Version 2.0.0

set -e

echo "=== Installation Pi Signage Web Interface ==="

# Vérifier les prérequis
command -v nginx >/dev/null 2>&1 || { echo "nginx requis mais non installé."; exit 1; }
command -v php >/dev/null 2>&1 || { echo "PHP requis mais non installé."; exit 1; }

# Variables
WEB_ROOT="/var/www/pi-signage"
NGINX_CONF="/etc/nginx/sites-available/pi-signage"

# Créer le répertoire web
echo "Création du répertoire web..."
sudo mkdir -p "$WEB_ROOT"

# Copier les fichiers
echo "Copie des fichiers..."
sudo cp -r ../src/* "$WEB_ROOT/"

# Permissions
echo "Configuration des permissions..."
sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"
sudo chmod -R 775 "$WEB_ROOT/temp"

# Configuration nginx
echo "Configuration nginx..."
sudo cp nginx.conf "$NGINX_CONF"
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/

# Test nginx
sudo nginx -t

# Redémarrage des services
echo "Redémarrage des services..."
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "✓ Installation terminée !"
echo "Accédez à l'interface : http://$(hostname -I | awk '{print $1}')/"
```

### 4. `api/upload.php` (à ajouter)
```php
<?php
/**
 * API Upload de vidéos
 */

session_start();
require_once '../includes/config.php';
require_once '../includes/functions.php';
require_once '../includes/session.php';

// Vérifier l'authentification
if (!isLoggedIn()) {
    http_response_code(401);
    die(json_encode(['error' => 'Non autorisé']));
}

// Vérifier la méthode
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['error' => 'Méthode non autorisée']));
}

// Vérifier le fichier
if (!isset($_FILES['video'])) {
    http_response_code(400);
    die(json_encode(['error' => 'Aucun fichier envoyé']));
}

$file = $_FILES['video'];

// Vérifier les erreurs
if ($file['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    die(json_encode(['error' => 'Erreur upload: ' . $file['error']]));
}

// Vérifier la taille
if ($file['size'] > MAX_UPLOAD_SIZE) {
    http_response_code(413);
    die(json_encode(['error' => 'Fichier trop volumineux']));
}

// Vérifier l'extension
$extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($extension, ALLOWED_VIDEO_FORMATS)) {
    http_response_code(415);
    die(json_encode(['error' => 'Format non supporté']));
}

// Générer un nom sûr
$safeName = preg_replace('/[^a-zA-Z0-9_-]/', '_', pathinfo($file['name'], PATHINFO_FILENAME));
$safeName = substr($safeName, 0, 100); // Limiter la longueur
$newName = $safeName . '_' . time() . '.' . $extension;
$destination = VIDEO_DIR . '/' . $newName;

// Déplacer le fichier
if (move_uploaded_file($file['tmp_name'], $destination)) {
    // Log
    logAction('Video upload', $newName);
    
    // Redémarrer VLC
    restartVLC();
    
    echo json_encode([
        'success' => true,
        'filename' => $newName,
        'size' => $file['size']
    ]);
} else {
    http_response_code(500);
    die(json_encode(['error' => 'Erreur lors du déplacement du fichier']));
}
```

### 5. `api/download.php` (endpoint pour YouTube)
```php
<?php
/**
 * API Téléchargement YouTube
 */

session_start();
require_once '../includes/config.php';
require_once '../includes/functions.php';
require_once '../includes/session.php';

// Configuration pour streaming
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');

// Vérifier l'authentification
if (!isLoggedIn()) {
    echo "data: " . json_encode(['error' => 'Non autorisé']) . "\n\n";
    exit;
}

// Récupérer les paramètres
$data = json_decode(file_get_contents('php://input'), true);
$url = $data['url'] ?? '';
$quality = $data['quality'] ?? '720p';

// Vérifier le token CSRF
if (!isset($data['csrf_token']) || $data['csrf_token'] !== $_SESSION['csrf_token']) {
    echo "data: " . json_encode(['error' => 'Token CSRF invalide']) . "\n\n";
    exit;
}

// Valider l'URL
if (!filter_var($url, FILTER_VALIDATE_URL)) {
    echo "data: " . json_encode(['error' => 'URL invalide']) . "\n\n";
    exit;
}

// Configuration yt-dlp
$format = match($quality) {
    '480p' => 'best[height<=480]/best',
    '720p' => 'best[height<=720]/best',
    '1080p' => 'best[height<=1080]/best',
    default => 'best'
};

// Commande yt-dlp avec progression
$cmd = sprintf(
    '%s -f "%s" -o "%s/%%(title)s.%%(ext)s" --restrict-filenames --no-playlist --newline --progress "%s" 2>&1',
    YTDLP_BIN,
    $format,
    VIDEO_DIR,
    escapeshellarg($url)
);

// Lancer le téléchargement
$descriptorspec = [
    0 => ["pipe", "r"],
    1 => ["pipe", "w"],
    2 => ["pipe", "w"]
];

$process = proc_open($cmd, $descriptorspec, $pipes);

if (is_resource($process)) {
    stream_set_blocking($pipes[1], 0);
    
    while (!feof($pipes[1])) {
        $line = fgets($pipes[1]);
        
        if ($line !== false) {
            // Parser la progression
            if (preg_match('/\[download\]\s+(\d+\.?\d*)%/', $line, $matches)) {
                echo "data: " . json_encode([
                    'progress' => floatval($matches[1]),
                    'status' => 'downloading'
                ]) . "\n\n";
                ob_flush();
                flush();
            }
        }
        
        usleep(100000); // 100ms
    }
    
    fclose($pipes[0]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    
    $return_value = proc_close($process);
    
    if ($return_value === 0) {
        restartVLC();
        echo "data: " . json_encode([
            'progress' => 100,
            'status' => 'completed'
        ]) . "\n\n";
    } else {
        echo "data: " . json_encode([
            'error' => 'Échec du téléchargement',
            'status' => 'error'
        ]) . "\n\n";
    }
}
```

## 🚀 Publication sur GitHub

### 1. Initialiser le repository
```bash
cd pi-signage-web
git init
git add .
git commit -m "Initial commit - Pi Signage Web Interface v2.0.0"
```

### 2. Créer le repository sur GitHub
- Allez sur https://github.com/new
- Nom : `pi-signage-web`
- Description : "Interface web moderne pour Pi Signage Digital"
- Public ou Private selon vos besoins

### 3. Pousser le code
```bash
git remote add origin https://github.com/VOTRE_USERNAME/pi-signage-web.git
git branch -M main
git push -u origin main
```

### 4. Ajouter les Topics GitHub
- `raspberry-pi`
- `digital-signage`
- `php`
- `web-interface`
- `youtube-downloader`

### 5. Configurer les GitHub Pages (optionnel)
Pour la documentation :
- Settings → Pages
- Source : Deploy from a branch
- Branch : main, /docs

## 📋 Checklist de Publication

- [ ] Tous les fichiers PHP créés et testés
- [ ] CSS et JavaScript fonctionnels
- [ ] README.md complet avec screenshots
- [ ] License ajoutée
- [ ] .gitignore configuré
- [ ] Scripts d'installation testés
- [ ] Documentation API complète
- [ ] Exemples de configuration
- [ ] Tests de sécurité effectués
- [ ] Version tagguée (v2.0.0)

---

Votre interface web est maintenant prête pour la publication sur GitHub ! 🎉