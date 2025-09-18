#!/bin/bash
# =============================================================================
# Module 02: Interface Web - PiSignage Desktop v3.0
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WEB_DIR="/var/www/pisignage"
BASE_DIR="/opt/pisignage"
VERBOSE=${VERBOSE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[WEB-INTERFACE] $1"
    fi
}

# Installation interface web
install_web_interface() {
    log "Installation de l'interface web..."
    
    # Copier les fichiers web
    if [[ -d "$PROJECT_DIR/web" ]]; then
        sudo cp -r "$PROJECT_DIR/web/"* "$WEB_DIR/"
    else
        # Créer une interface minimaliste si pas de dossier web
        create_minimal_interface
    fi
    
    # Permissions
    sudo chown -R www-data:www-data "$WEB_DIR"
    sudo chmod -R 755 "$WEB_DIR"
    
    echo -e "${GREEN}✓ Interface web installée${NC}"
}

# Créer interface minimaliste
create_minimal_interface() {
    log "Création interface web minimaliste..."
    
    # Index.php - Dashboard
    cat > /tmp/index.php << 'EOF'
<?php
session_start();
$videos_dir = '/opt/pisignage/videos';
$videos = glob($videos_dir . '/*.{mp4,avi,mkv,mov,webm}', GLOB_BRACE);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage Desktop v3.0</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, system-ui, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { margin-bottom: 30px; text-align: center; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { opacity: 0.8; margin-top: 5px; }
        .videos-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .video-card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            padding: 15px;
            border-radius: 10px;
        }
        .controls {
            margin-top: 20px;
            display: flex;
            gap: 10px;
            justify-content: center;
        }
        button {
            padding: 10px 20px;
            background: white;
            color: #667eea;
            border: none;
            border-radius: 5px;
            font-weight: bold;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover { transform: scale(1.05); }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ PiSignage Desktop v3.0</h1>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value"><?php echo count($videos); ?></div>
                <div class="stat-label">Vidéos</div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><?php echo round(disk_free_space('/') / 1073741824, 1); ?> GB</div>
                <div class="stat-label">Espace libre</div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><?php echo round(memory_get_usage() / 1048576, 1); ?> MB</div>
                <div class="stat-label">RAM utilisée</div>
            </div>
            <div class="stat-card">
                <div class="stat-value"><?php echo date('H:i'); ?></div>
                <div class="stat-label">Heure système</div>
            </div>
        </div>
        
        <h2>📹 Vidéos disponibles</h2>
        <div class="videos-grid">
            <?php foreach($videos as $video): ?>
            <div class="video-card">
                <h3><?php echo basename($video); ?></h3>
                <p>Taille: <?php echo round(filesize($video) / 1048576, 1); ?> MB</p>
                <button onclick="playVideo('<?php echo basename($video); ?>')">Lire</button>
            </div>
            <?php endforeach; ?>
        </div>
        
        <div class="controls">
            <button onclick="controlPlayer('play')">▶️ Play</button>
            <button onclick="controlPlayer('pause')">⏸️ Pause</button>
            <button onclick="controlPlayer('stop')">⏹️ Stop</button>
            <button onclick="controlPlayer('restart')">🔄 Redémarrer</button>
        </div>
    </div>
    
    <script>
        function controlPlayer(action) {
            fetch('/api/control.php?action=' + action)
                .then(r => r.json())
                .then(data => console.log(data));
        }
        
        function playVideo(video) {
            fetch('/api/control.php?action=play&video=' + encodeURIComponent(video))
                .then(r => r.json())
                .then(data => console.log(data));
        }
    </script>
</body>
</html>
EOF
    
    # API control.php
    cat > /tmp/control.php << 'EOF'
<?php
header('Content-Type: application/json');

$action = $_GET['action'] ?? '';
$video = $_GET['video'] ?? '';

$response = ['status' => 'error', 'message' => 'Action non reconnue'];

switch($action) {
    case 'play':
        if ($video) {
            exec("DISPLAY=:0 chromium-browser --kiosk --autoplay-policy=no-user-gesture-required file:///opt/pisignage/videos/$video &");
        }
        $response = ['status' => 'success', 'action' => 'play', 'video' => $video];
        break;
    
    case 'pause':
        exec("xdotool key space");
        $response = ['status' => 'success', 'action' => 'pause'];
        break;
        
    case 'stop':
        exec("pkill -f chromium");
        $response = ['status' => 'success', 'action' => 'stop'];
        break;
        
    case 'restart':
        exec("sudo systemctl restart pisignage");
        $response = ['status' => 'success', 'action' => 'restart'];
        break;
}

echo json_encode($response);
?>
EOF
    
    # Copier les fichiers
    sudo cp /tmp/index.php "$WEB_DIR/index.php"
    sudo mkdir -p "$WEB_DIR/api"
    sudo cp /tmp/control.php "$WEB_DIR/api/control.php"
    
    rm /tmp/index.php /tmp/control.php
}

# Configuration Nginx
configure_nginx() {
    log "Configuration de Nginx..."
    
    # Configuration Nginx
    cat > /tmp/pisignage.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/pisignage;
    index index.php index.html;
    
    # Logs
    access_log /var/log/nginx/pisignage_access.log;
    error_log /var/log/nginx/pisignage_error.log;
    
    # PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    # Sécurité
    location ~ /\. {
        deny all;
    }
    
    # Cache pour assets
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 7d;
    }
    
    # Upload de vidéos
    client_max_body_size 500M;
    client_body_timeout 300s;
}
EOF
    
    # Installer la configuration
    sudo cp /tmp/pisignage.conf /etc/nginx/sites-available/pisignage
    sudo ln -sf /etc/nginx/sites-available/pisignage /etc/nginx/sites-enabled/
    
    # Désactiver le site par défaut
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Tester et recharger Nginx
    sudo nginx -t && sudo systemctl reload nginx
    
    echo -e "${GREEN}✓ Nginx configuré${NC}"
    
    rm /tmp/pisignage.conf
}

# Configuration PHP-FPM
configure_php() {
    log "Configuration de PHP-FPM..."
    
    # Déterminer la version de PHP
    PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.2")
    PHP_FPM_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"
    
    # Ajuster la config si le socket existe
    if [[ -S "$PHP_FPM_SOCK" ]]; then
        sudo sed -i "s|/var/run/php/php-fpm.sock|$PHP_FPM_SOCK|" /etc/nginx/sites-available/pisignage
    fi
    
    # Optimisations PHP pour Raspberry Pi
    PHP_INI="/etc/php/$PHP_VERSION/fpm/php.ini"
    if [[ -f "$PHP_INI" ]]; then
        sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 500M/' "$PHP_INI"
        sudo sed -i 's/post_max_size = .*/post_max_size = 500M/' "$PHP_INI"
        sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
        
        sudo systemctl restart "php${PHP_VERSION}-fpm"
    fi
    
    echo -e "${GREEN}✓ PHP-FPM configuré${NC}"
}

# Créer base de données SQLite
create_database() {
    log "Création de la base de données SQLite..."
    
    DB_FILE="$BASE_DIR/config/pisignage.db"
    
    # Créer la structure
    sqlite3 "$DB_FILE" << 'EOF'
CREATE TABLE IF NOT EXISTS playlist (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    duration INTEGER DEFAULT 10,
    enabled INTEGER DEFAULT 1,
    position INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO settings (key, value) VALUES 
    ('admin_password', 'admin'),
    ('autoplay', '1'),
    ('transition_time', '1'),
    ('default_duration', '10');
EOF
    
    # Permissions
    sudo chown www-data:www-data "$DB_FILE"
    sudo chmod 664 "$DB_FILE"
    
    echo -e "${GREEN}✓ Base de données créée${NC}"
}

# Main
main() {
    echo "Module 2: Interface Web"
    echo "========================"
    
    install_web_interface
    configure_nginx
    configure_php
    create_database
    
    echo ""
    echo -e "${GREEN}✓ Module interface web terminé${NC}"
    echo "  Accès: http://$(hostname -I | cut -d' ' -f1)/"
    
    return 0
}

# Exécution
main "$@"