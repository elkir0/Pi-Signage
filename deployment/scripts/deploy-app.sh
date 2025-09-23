#!/bin/bash

# PiSignage v0.9.0 - Script de Déploiement de l'Application
# Déploie l'application PiSignage depuis le dépôt local

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DEPLOY_LOG="/tmp/pisignage-app-deploy.log"
PISIGNAGE_DIR="/opt/pisignage"
SOURCE_DIR="/tmp/deployment"
VERSION="0.9.0"

# Fonction de log
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$DEPLOY_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$DEPLOY_LOG"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$DEPLOY_LOG"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$DEPLOY_LOG"
            ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$DEPLOY_LOG"
}

# Fonction d'exécution avec gestion d'erreur
execute_safely() {
    local command="$1"
    local description="$2"

    log "INFO" "$description"
    if eval "$command" >> "$DEPLOY_LOG" 2>&1; then
        log "SUCCESS" "$description réussi"
        return 0
    else
        log "ERROR" "$description échoué"
        log "ERROR" "Commande: $command"
        return 1
    fi
}

# Copier l'application depuis la source
copy_application_files() {
    log "INFO" "Copie des fichiers de l'application..."

    # Vérifier que le répertoire source existe
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log "ERROR" "Répertoire source non trouvé: $SOURCE_DIR"
        return 1
    fi

    # Créer la structure de répertoires
    execute_safely "sudo mkdir -p $PISIGNAGE_DIR/{web,scripts,config,media,logs,screenshots}" "Création de la structure de répertoires"

    # Copier les fichiers web
    if [[ -d "$SOURCE_DIR/web" ]]; then
        execute_safely "sudo cp -r $SOURCE_DIR/web/* $PISIGNAGE_DIR/web/" "Copie des fichiers web"
    else
        log "WARN" "Répertoire web source non trouvé"
    fi

    # Copier les scripts
    if [[ -d "$SOURCE_DIR/scripts" ]]; then
        execute_safely "sudo cp -r $SOURCE_DIR/scripts/* $PISIGNAGE_DIR/scripts/" "Copie des scripts"
        execute_safely "sudo chmod +x $PISIGNAGE_DIR/scripts/*.sh" "Permissions des scripts"
    else
        log "WARN" "Répertoire scripts source non trouvé"
    fi

    # Copier les fichiers de configuration
    if [[ -d "$SOURCE_DIR/config" ]]; then
        execute_safely "sudo cp -r $SOURCE_DIR/config/* $PISIGNAGE_DIR/config/" "Copie des configurations"
    fi

    # Copier le fichier VERSION
    if [[ -f "$SOURCE_DIR/VERSION" ]]; then
        execute_safely "sudo cp $SOURCE_DIR/VERSION $PISIGNAGE_DIR/" "Copie du fichier VERSION"
    fi

    # Copier README et documentation
    for file in README.md INSTALLATION-GUIDE.md; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            execute_safely "sudo cp $SOURCE_DIR/$file $PISIGNAGE_DIR/" "Copie de $file"
        fi
    done

    return 0
}

# Télécharger l'application depuis GitHub (fallback)
download_from_github() {
    log "INFO" "Téléchargement depuis GitHub..."

    local github_url="https://github.com/elkir0/Pi-Signage"
    local temp_dir="/tmp/pisignage-github"

    # Nettoyer le répertoire temporaire
    rm -rf "$temp_dir"

    # Cloner le dépôt
    if ! execute_safely "git clone $github_url $temp_dir" "Clonage du dépôt GitHub"; then
        return 1
    fi

    # Checkout de la version 0.9.0
    cd "$temp_dir"
    if ! execute_safely "git checkout v0.9.0" "Checkout version 0.9.0"; then
        log "WARN" "Version 0.9.0 non trouvée, utilisation de main"
        execute_safely "git checkout main" "Checkout branche main"
    fi

    # Copier les fichiers
    execute_safely "sudo cp -r $temp_dir/* $PISIGNAGE_DIR/" "Copie depuis GitHub"

    # Nettoyer
    rm -rf "$temp_dir"

    return 0
}

# Créer les scripts de contrôle
create_control_scripts() {
    log "INFO" "Création des scripts de contrôle..."

    # Script de démarrage
    local start_script="$PISIGNAGE_DIR/scripts/start-signage.sh"
    cat << 'EOF' | sudo tee "$start_script" > /dev/null
#!/bin/bash

# PiSignage Start Script
PISIGNAGE_DIR="/opt/pisignage"
LOG_FILE="$PISIGNAGE_DIR/logs/system.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Démarrage de PiSignage v0.9.0"

# Vérifier les services requis
for service in nginx php7.4-fpm; do
    if ! systemctl is-active "$service" &>/dev/null; then
        log "Démarrage du service: $service"
        sudo systemctl start "$service"
    fi
done

# Créer les répertoires manquants
mkdir -p "$PISIGNAGE_DIR"/{media,logs,screenshots}

# Vérifier les permissions
sudo chown -R pi:www-data "$PISIGNAGE_DIR"
sudo chmod -R 775 "$PISIGNAGE_DIR"/{media,logs,screenshots}

log "PiSignage démarré avec succès"

# Maintenir le processus actif
while true; do
    sleep 60

    # Vérification de santé basique
    if ! curl -s http://localhost >/dev/null; then
        log "WARN: Interface web non accessible"
    fi
done
EOF

    # Script d'arrêt
    local stop_script="$PISIGNAGE_DIR/scripts/stop-signage.sh"
    cat << 'EOF' | sudo tee "$stop_script" > /dev/null
#!/bin/bash

# PiSignage Stop Script
PISIGNAGE_DIR="/opt/pisignage"
LOG_FILE="$PISIGNAGE_DIR/logs/system.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Arrêt de PiSignage v0.9.0"

# Arrêter le mode kiosk si actif
if systemctl is-active pisignage-kiosk &>/dev/null; then
    sudo systemctl stop pisignage-kiosk
    log "Mode kiosk arrêté"
fi

log "PiSignage arrêté"
EOF

    # Rendre les scripts exécutables
    sudo chmod +x "$start_script" "$stop_script"

    log "SUCCESS" "Scripts de contrôle créés"
    return 0
}

# Déployer l'interface web
deploy_web_interface() {
    log "INFO" "Déploiement de l'interface web..."

    # Si pas d'interface web copiée, créer une interface basique
    if [[ ! -f "$PISIGNAGE_DIR/web/index.php" ]]; then
        log "INFO" "Création d'une interface web basique..."

        cat << 'EOF' | sudo tee "$PISIGNAGE_DIR/web/index.php" > /dev/null
<?php
/**
 * PiSignage v0.9.0 - Interface Web Principale
 * Interface d'administration et de contrôle
 */

header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v0.9.0 - Digital Signage</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        .header h1 {
            font-size: 2.5em;
            margin: 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .version {
            opacity: 0.8;
            font-size: 1.2em;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 40px;
        }
        .card {
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            padding: 30px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
        }
        .card h3 {
            margin-top: 0;
            color: #fff;
            font-size: 1.5em;
        }
        .status {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin: 10px 0;
        }
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #4CAF50;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(76, 175, 80, 0); }
            100% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0); }
        }
        .btn {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 25px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            margin: 5px;
            transition: all 0.3s ease;
        }
        .btn:hover {
            transform: scale(1.05);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .system-info {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 15px;
            margin: 15px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ PiSignage</h1>
            <div class="version">Version 0.9.0 - Digital Signage System</div>
        </div>

        <div class="grid">
            <div class="card">
                <h3>📊 État du Système</h3>
                <div class="status">
                    <span>Serveur Web</span>
                    <div class="status-indicator"></div>
                </div>
                <div class="status">
                    <span>PHP</span>
                    <div class="status-indicator"></div>
                </div>
                <div class="status">
                    <span>Interface</span>
                    <div class="status-indicator"></div>
                </div>

                <div class="system-info">
                    <strong>Informations Système:</strong><br>
                    OS: <?php echo php_uname('s') . ' ' . php_uname('r'); ?><br>
                    PHP: <?php echo PHP_VERSION; ?><br>
                    Serveur: <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'Nginx'; ?><br>
                    Heure: <?php echo date('d/m/Y H:i:s'); ?>
                </div>
            </div>

            <div class="card">
                <h3>🎬 Gestion Média</h3>
                <p>Gérez vos contenus d'affichage</p>
                <a href="/api/media.php" class="btn">📁 Parcourir Médias</a>
                <a href="/api/upload.php" class="btn">⬆️ Upload</a>
                <a href="/media/" class="btn">📂 Dossier Média</a>
            </div>

            <div class="card">
                <h3>📋 Playlists</h3>
                <p>Organisez vos séquences d'affichage</p>
                <a href="/api/playlist.php" class="btn">📝 Gérer Playlists</a>
                <a href="/api/schedule.php" class="btn">⏰ Programmer</a>
            </div>

            <div class="card">
                <h3>📸 Capture d'Écran</h3>
                <p>Surveillez l'affichage en temps réel</p>
                <a href="/api/screenshot.php" class="btn">📷 Capturer</a>
                <a href="/screenshots/" class="btn">🖼️ Galerie</a>
            </div>

            <div class="card">
                <h3>⚙️ Configuration</h3>
                <p>Paramètres système et affichage</p>
                <a href="/api/system.php" class="btn">🔧 Système</a>
                <a href="/api/config.php" class="btn">⚙️ Config</a>
                <a href="/logs/" class="btn">📄 Logs</a>
            </div>

            <div class="card">
                <h3>🌐 APIs Disponibles</h3>
                <div style="font-size: 0.9em;">
                    <a href="/api/system.php" class="btn">System API</a>
                    <a href="/api/media.php" class="btn">Media API</a>
                    <a href="/api/playlist.php" class="btn">Playlist API</a>
                    <a href="/api/screenshot.php" class="btn">Screenshot API</a>
                </div>
            </div>
        </div>

        <div style="text-align: center; margin-top: 40px; opacity: 0.7;">
            <p>PiSignage v0.9.0 - Système d'affichage digital pour Raspberry Pi</p>
            <p>🚀 Optimisé pour Chromium Kiosk 30+ FPS</p>
        </div>
    </div>

    <script>
        // Vérification périodique du statut
        setInterval(() => {
            fetch('/api/system.php')
                .then(response => response.json())
                .then(data => {
                    console.log('Status check:', data);
                })
                .catch(error => {
                    console.log('Status check failed:', error);
                });
        }, 30000);

        // Animation d'entrée
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.card');
            cards.forEach((card, index) => {
                card.style.animation = `fadeInUp 0.6s ease forwards ${index * 0.1}s`;
            });
        });
    </script>

    <style>
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        .card {
            opacity: 0;
        }
    </style>
</body>
</html>
EOF

        # Créer les APIs basiques
        sudo mkdir -p "$PISIGNAGE_DIR/web/api"

        # API System
        cat << 'EOF' | sudo tee "$PISIGNAGE_DIR/web/api/system.php" > /dev/null
<?php
header('Content-Type: application/json');

$system_info = [
    'status' => 'ok',
    'version' => '0.9.0',
    'timestamp' => date('c'),
    'system' => [
        'os' => php_uname('s') . ' ' . php_uname('r'),
        'php' => PHP_VERSION,
        'server' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
        'load' => sys_getloadavg()[0] ?? 0,
        'uptime' => shell_exec('uptime -p') ?? 'Unknown'
    ],
    'services' => [
        'nginx' => shell_exec('systemctl is-active nginx 2>/dev/null') === "active\n",
        'php' => function_exists('phpinfo'),
        'pisignage' => file_exists('/opt/pisignage/VERSION')
    ]
];

echo json_encode($system_info, JSON_PRETTY_PRINT);
?>
EOF

        # API Media basique
        cat << 'EOF' | sudo tee "$PISIGNAGE_DIR/web/api/media.php" > /dev/null
<?php
header('Content-Type: application/json');

$media_dir = '/opt/pisignage/media';
$media_files = [];

if (is_dir($media_dir)) {
    $files = scandir($media_dir);
    foreach ($files as $file) {
        if ($file !== '.' && $file !== '..' && !is_dir($media_dir . '/' . $file)) {
            $media_files[] = [
                'name' => $file,
                'size' => filesize($media_dir . '/' . $file),
                'modified' => filemtime($media_dir . '/' . $file),
                'url' => '/media/' . $file
            ];
        }
    }
}

echo json_encode([
    'status' => 'ok',
    'media_count' => count($media_files),
    'media_files' => $media_files
], JSON_PRETTY_PRINT);
?>
EOF

        log "SUCCESS" "Interface web basique créée"
    fi

    return 0
}

# Configurer les permissions finales
configure_final_permissions() {
    log "INFO" "Configuration des permissions finales..."

    # Propriétaire principal
    execute_safely "sudo chown -R pi:pi $PISIGNAGE_DIR" "Propriétaire principal (pi:pi)"

    # Permissions pour www-data
    execute_safely "sudo chgrp -R www-data $PISIGNAGE_DIR/web" "Groupe www-data pour web"
    execute_safely "sudo chgrp -R www-data $PISIGNAGE_DIR/media" "Groupe www-data pour media"
    execute_safely "sudo chgrp -R www-data $PISIGNAGE_DIR/logs" "Groupe www-data pour logs"
    execute_safely "sudo chgrp -R www-data $PISIGNAGE_DIR/screenshots" "Groupe www-data pour screenshots"

    # Permissions d'écriture
    execute_safely "sudo chmod -R 775 $PISIGNAGE_DIR/media" "Permissions media"
    execute_safely "sudo chmod -R 775 $PISIGNAGE_DIR/logs" "Permissions logs"
    execute_safely "sudo chmod -R 775 $PISIGNAGE_DIR/screenshots" "Permissions screenshots"
    execute_safely "sudo chmod -R 755 $PISIGNAGE_DIR/web" "Permissions web"

    # Scripts exécutables
    execute_safely "sudo chmod +x $PISIGNAGE_DIR/scripts/*.sh" "Scripts exécutables"

    log "SUCCESS" "Permissions configurées"
    return 0
}

# Démarrer les services
start_services() {
    log "INFO" "Démarrage des services..."

    local services=("nginx" "php7.4-fpm" "pisignage")

    for service in "${services[@]}"; do
        if execute_safely "sudo systemctl start $service" "Démarrage $service"; then
            execute_safely "sudo systemctl enable $service" "Activation $service"
        else
            log "WARN" "Problème avec le service $service"
        fi
    done

    # Vérifier que nginx répond
    sleep 5
    if curl -s http://localhost >/dev/null; then
        log "SUCCESS" "Interface web accessible"
    else
        log "WARN" "Interface web non accessible immédiatement"
    fi

    return 0
}

# Fonction principale
main() {
    echo "PiSignage v0.9.0 - Déploiement Application"
    echo "========================================="
    echo

    log "INFO" "Début du déploiement de l'application..."
    log "INFO" "Log détaillé: $DEPLOY_LOG"

    # Vérifier les permissions
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log "ERROR" "Permissions sudo requises"
        return 1
    fi

    # Étapes de déploiement
    local steps=(
        "copy_application_files"
        "create_control_scripts"
        "deploy_web_interface"
        "configure_final_permissions"
        "start_services"
    )

    for step in "${steps[@]}"; do
        log "INFO" "Exécution: $step"
        if ! $step; then
            log "ERROR" "Échec à l'étape: $step"
            # Essayer un fallback pour copy_application_files
            if [[ "$step" == "copy_application_files" ]]; then
                log "INFO" "Tentative de téléchargement depuis GitHub..."
                if ! download_from_github; then
                    return 1
                fi
            else
                return 1
            fi
        fi
        echo
    done

    log "SUCCESS" "Déploiement de l'application terminé avec succès"
    log "INFO" "Interface accessible sur: http://localhost"
    log "INFO" "Répertoire: $PISIGNAGE_DIR"

    return 0
}

# Exécution si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi