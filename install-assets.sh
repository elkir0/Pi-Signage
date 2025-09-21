#!/bin/bash

# Script d'installation des assets Bootstrap et jQuery
set -e

PRODUCTION_IP="192.168.1.103"
PRODUCTION_USER="pi"
PRODUCTION_PASS="raspberry"

echo "📦 INSTALLATION DES ASSETS (Bootstrap, jQuery)"
echo "=============================================="

cat > /tmp/install_assets.sh << 'ASSETS'
#!/bin/bash
set -e

echo "📥 1. Téléchargement des librairies..."
cd /var/www/html/web/assets

# Créer les dossiers vendor
sudo mkdir -p vendor/bootstrap/css
sudo mkdir -p vendor/bootstrap/js
sudo mkdir -p vendor/jquery
sudo mkdir -p vendor/fontawesome/css

echo "📦 2. Installation de Bootstrap 5..."
sudo wget -q -O vendor/bootstrap/css/bootstrap.min.css https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css
sudo wget -q -O vendor/bootstrap/js/bootstrap.bundle.min.js https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js

echo "📦 3. Installation de jQuery..."
sudo wget -q -O vendor/jquery/jquery.min.js https://code.jquery.com/jquery-3.7.1.min.js

echo "📦 4. Installation de Font Awesome..."
sudo wget -q -O vendor/fontawesome/css/all.min.css https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css

echo "📝 5. Création d'un index.php corrigé..."
sudo tee /var/www/html/web/index-fixed.php << 'PHP'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage - Système de Gestion v0.9.4</title>
    
    <!-- Bootstrap CSS -->
    <link href="assets/vendor/bootstrap/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome -->
    <link href="assets/vendor/fontawesome/css/all.min.css" rel="stylesheet">
    <!-- Custom CSS -->
    <link href="assets/css/style.css" rel="stylesheet">
    
    <style>
        .navbar-brand { font-weight: bold; }
        .tab-content { padding: 20px; background: white; border-radius: 0 0 8px 8px; }
        .card { margin-bottom: 20px; }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
        <div class="container-fluid">
            <a class="navbar-brand" href="#">
                <i class="fas fa-tv"></i> PiSignage v0.9.4
            </a>
            <span class="navbar-text">
                <i class="fas fa-server"></i> Serveur: <?php echo gethostname(); ?>
            </span>
        </div>
    </nav>

    <div class="container-fluid mt-3">
        <ul class="nav nav-tabs" id="mainTabs" role="tablist">
            <li class="nav-item">
                <a class="nav-link active" data-bs-toggle="tab" href="#dashboard">
                    <i class="fas fa-dashboard"></i> Dashboard
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" data-bs-toggle="tab" href="#playlist">
                    <i class="fas fa-list"></i> Playlists
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" data-bs-toggle="tab" href="#media">
                    <i class="fas fa-photo-video"></i> Médias
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" data-bs-toggle="tab" href="#youtube">
                    <i class="fab fa-youtube"></i> YouTube
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" data-bs-toggle="tab" href="#settings">
                    <i class="fas fa-cog"></i> Paramètres
                </a>
            </li>
        </ul>

        <div class="tab-content">
            <div class="tab-pane fade show active" id="dashboard">
                <h3>Dashboard</h3>
                <div class="row">
                    <div class="col-md-3">
                        <div class="card bg-primary text-white">
                            <div class="card-body">
                                <h5>État VLC</h5>
                                <p id="vlc-status">Vérification...</p>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card bg-success text-white">
                            <div class="card-body">
                                <h5>Médias</h5>
                                <p id="media-count">0 fichiers</p>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card bg-info text-white">
                            <div class="card-body">
                                <h5>Playlists</h5>
                                <p id="playlist-count">0 playlists</p>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="card bg-warning text-white">
                            <div class="card-body">
                                <h5>Système</h5>
                                <p id="system-info">OK</p>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="mt-4">
                    <h4>Actions rapides</h4>
                    <button class="btn btn-success" onclick="startVLC()">
                        <i class="fas fa-play"></i> Démarrer VLC
                    </button>
                    <button class="btn btn-danger" onclick="stopVLC()">
                        <i class="fas fa-stop"></i> Arrêter VLC
                    </button>
                    <a href="playlist-manager.html" class="btn btn-primary">
                        <i class="fas fa-list-alt"></i> Gestionnaire de playlists
                    </a>
                </div>
            </div>

            <div class="tab-pane fade" id="playlist">
                <h3>Gestion des Playlists</h3>
                <div id="playlist-content">
                    <p>Chargement des playlists...</p>
                </div>
            </div>

            <div class="tab-pane fade" id="media">
                <h3>Gestion des Médias</h3>
                <div id="media-content">
                    <p>Chargement des médias...</p>
                </div>
            </div>

            <div class="tab-pane fade" id="youtube">
                <h3>YouTube Downloader</h3>
                <div class="card">
                    <div class="card-body">
                        <input type="text" id="youtube-url" class="form-control mb-2" placeholder="URL YouTube">
                        <button class="btn btn-primary" onclick="downloadYouTube()">
                            <i class="fas fa-download"></i> Télécharger
                        </button>
                    </div>
                </div>
            </div>

            <div class="tab-pane fade" id="settings">
                <h3>Paramètres</h3>
                <div class="card">
                    <div class="card-body">
                        <h5>Configuration système</h5>
                        <p>Version: 0.9.4</p>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- jQuery -->
    <script src="assets/vendor/jquery/jquery.min.js"></script>
    <!-- Bootstrap JS -->
    <script src="assets/vendor/bootstrap/js/bootstrap.bundle.min.js"></script>
    
    <script>
        // Initialisation
        $(document).ready(function() {
            console.log('Interface chargée');
            loadStatus();
        });

        function loadStatus() {
            $.get('api/control.php?action=status', function(data) {
                $('#vlc-status').text(data.status || 'Arrêté');
            });
            
            $.get('api/playlist.php?action=list', function(data) {
                if(data.playlists) {
                    $('#playlist-count').text(data.playlists.length + ' playlists');
                }
            });
        }

        function startVLC() {
            $.get('api/control.php?action=start', function(data) {
                alert('VLC démarré');
                loadStatus();
            });
        }

        function stopVLC() {
            $.get('api/control.php?action=stop', function(data) {
                alert('VLC arrêté');
                loadStatus();
            });
        }

        function downloadYouTube() {
            const url = $('#youtube-url').val();
            if(!url) {
                alert('Veuillez entrer une URL YouTube');
                return;
            }
            
            $.post('api/youtube-enhanced.php', {
                action: 'download',
                url: url
            }, function(data) {
                alert('Téléchargement lancé');
            });
        }
    </script>
</body>
</html>
PHP

echo "6️⃣ Sauvegarde et remplacement..."
sudo mv /var/www/html/web/index.php /var/www/html/web/index-old.php
sudo mv /var/www/html/web/index-fixed.php /var/www/html/web/index.php

echo "7️⃣ Permissions..."
sudo chown -R www-data:www-data /var/www/html/web/assets/vendor
sudo chmod -R 755 /var/www/html/web/assets/vendor

echo "8️⃣ Vérification..."
echo "Assets installés:"
ls -la /var/www/html/web/assets/vendor/

echo "✅ Assets installés avec succès!"
ASSETS

echo "🚀 Installation sur le serveur..."
sshpass -p "$PRODUCTION_PASS" scp /tmp/install_assets.sh $PRODUCTION_USER@$PRODUCTION_IP:/tmp/
sshpass -p "$PRODUCTION_PASS" ssh $PRODUCTION_USER@$PRODUCTION_IP "bash /tmp/install_assets.sh"

echo ""
echo "✅ INSTALLATION TERMINÉE!"
echo "Interface disponible sur: http://$PRODUCTION_IP"