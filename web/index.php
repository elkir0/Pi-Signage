<?php
/**
 * PiSignage v0.8.0
 * Digital Signage Solution for Raspberry Pi
 *
 * This is the main interface file
 */

// Configuration
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Version
define('VERSION', '0.8.0');
define('TITLE', 'PiSignage v0.8.0');

// API endpoints
define('API_PATH', '/api/');

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo TITLE; ?></title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #1a1a1a;
            color: #ffffff;
            min-height: 100vh;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.3);
        }

        .header h1 {
            font-size: 28px;
            font-weight: 600;
        }

        .header .version {
            opacity: 0.8;
            font-size: 14px;
            margin-top: 5px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 30px;
            border-bottom: 2px solid #333;
            padding-bottom: 10px;
        }

        .tab {
            padding: 10px 20px;
            background: #2a2a2a;
            border: none;
            color: #fff;
            cursor: pointer;
            border-radius: 5px 5px 0 0;
            transition: all 0.3s;
        }

        .tab:hover {
            background: #3a3a3a;
        }

        .tab.active {
            background: #667eea;
        }

        .content {
            background: #2a2a2a;
            padding: 30px;
            border-radius: 10px;
            min-height: 400px;
        }

        .card {
            background: #333;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }

        .card h3 {
            margin-bottom: 15px;
            color: #667eea;
        }

        .button {
            background: #667eea;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            transition: all 0.3s;
        }

        .button:hover {
            background: #764ba2;
            transform: translateY(-2px);
        }

        .status {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }

        .status.online {
            background: #10b981;
            color: white;
        }

        .status.offline {
            background: #ef4444;
            color: white;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1>🖥️ <?php echo TITLE; ?></h1>
            <div class="version">Digital Signage pour Raspberry Pi</div>
        </div>
    </div>

    <div class="container">
        <div class="tabs">
            <button class="tab active" onclick="showTab('dashboard')">Dashboard</button>
            <button class="tab" onclick="showTab('media')">Médias</button>
            <button class="tab" onclick="showTab('playlist')">Playlists</button>
            <button class="tab" onclick="showTab('youtube')">YouTube</button>
            <button class="tab" onclick="showTab('schedule')">Programmation</button>
            <button class="tab" onclick="showTab('settings')">Paramètres</button>
            <button class="tab" onclick="showTab('system')">Système</button>
        </div>

        <div class="content" id="content">
            <div id="dashboard" class="tab-content">
                <h2>Tableau de bord</h2>

                <div class="grid">
                    <div class="card">
                        <h3>📊 État du système</h3>
                        <p>CPU: <span id="cpu">--</span>%</p>
                        <p>RAM: <span id="ram">--</span>%</p>
                        <p>Température: <span id="temp">--</span>°C</p>
                        <p>Uptime: <span id="uptime">--</span></p>
                        <p class="status online">En ligne</p>
                    </div>

                    <div class="card">
                        <h3>🎬 Lecteur vidéo</h3>
                        <p>État: <span id="player-status">Arrêté</span></p>
                        <p>Fichier: <span id="current-file">Aucun</span></p>
                        <button class="button" onclick="playerControl('play')">▶ Play</button>
                        <button class="button" onclick="playerControl('stop')">⏹ Stop</button>
                    </div>

                    <div class="card">
                        <h3>📁 Stockage</h3>
                        <p>Utilisé: <span id="disk-used">--</span> GB</p>
                        <p>Libre: <span id="disk-free">--</span> GB</p>
                        <p>Total: <span id="disk-total">--</span> GB</p>
                    </div>

                    <div class="card">
                        <h3>🔄 Actions rapides</h3>
                        <button class="button" onclick="quickAction('restart')">Redémarrer lecteur</button>
                        <button class="button" onclick="quickAction('clear-cache')">Vider cache</button>
                        <button class="button" onclick="quickAction('screenshot')">Capture écran</button>
                    </div>
                </div>
            </div>

            <div id="media" class="tab-content" style="display:none;">
                <h2>Bibliothèque de médias</h2>
                <div class="card">
                    <h3>📤 Upload de fichiers</h3>
                    <input type="file" id="file-upload" multiple accept="video/*,image/*">
                    <button class="button" onclick="uploadFiles()">Envoyer</button>
                </div>
                <div class="card">
                    <h3>📁 Fichiers disponibles</h3>
                    <div id="media-list">Chargement...</div>
                </div>
            </div>

            <div id="playlist" class="tab-content" style="display:none;">
                <h2>Gestion des playlists</h2>
                <div class="card">
                    <h3>➕ Nouvelle playlist</h3>
                    <input type="text" id="playlist-name" placeholder="Nom de la playlist">
                    <button class="button" onclick="createPlaylist()">Créer</button>
                </div>
                <div class="card">
                    <h3>📋 Playlists existantes</h3>
                    <div id="playlist-list">Chargement...</div>
                </div>
            </div>

            <div id="youtube" class="tab-content" style="display:none;">
                <h2>Téléchargement YouTube</h2>
                <div class="card">
                    <h3>📺 Télécharger une vidéo</h3>
                    <input type="url" id="youtube-url" placeholder="https://youtube.com/watch?v=...">
                    <select id="youtube-quality">
                        <option value="best">Meilleure qualité</option>
                        <option value="720">720p</option>
                        <option value="480">480p</option>
                        <option value="360">360p</option>
                    </select>
                    <button class="button" onclick="downloadYoutube()">Télécharger</button>
                </div>
                <div class="card">
                    <h3>📥 File d'attente</h3>
                    <div id="download-queue">Aucun téléchargement</div>
                </div>
            </div>

            <div id="schedule" class="tab-content" style="display:none;">
                <h2>Programmation</h2>
                <div class="card">
                    <h3>📅 Calendrier</h3>
                    <p>Fonctionnalité en développement</p>
                </div>
            </div>

            <div id="settings" class="tab-content" style="display:none;">
                <h2>Paramètres</h2>
                <div class="card">
                    <h3>⚙️ Configuration générale</h3>
                    <p>Version: <?php echo VERSION; ?></p>
                    <p>Mode: Production</p>
                    <button class="button" onclick="saveSettings()">Sauvegarder</button>
                </div>
            </div>

            <div id="system" class="tab-content" style="display:none;">
                <h2>Système</h2>
                <div class="card">
                    <h3>🖥️ Informations système</h3>
                    <button class="button" onclick="systemAction('reboot')">Redémarrer Pi</button>
                    <button class="button" onclick="systemAction('shutdown')">Éteindre</button>
                    <button class="button" onclick="systemAction('update')">Mettre à jour</button>
                </div>
                <div class="card">
                    <h3>📜 Logs</h3>
                    <div id="system-logs" style="background: #000; padding: 10px; font-family: monospace; height: 200px; overflow-y: auto;">
                        Chargement des logs...
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Tab management
        function showTab(tabName) {
            // Hide all tabs
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.style.display = 'none';
            });

            // Remove active class from all tab buttons
            document.querySelectorAll('.tab').forEach(btn => {
                btn.classList.remove('active');
            });

            // Show selected tab
            document.getElementById(tabName).style.display = 'block';

            // Add active class to clicked button
            event.target.classList.add('active');
        }

        // API calls
        async function apiCall(endpoint, method = 'GET', data = null) {
            try {
                const options = {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json'
                    }
                };

                if (data) {
                    options.body = JSON.stringify(data);
                }

                const response = await fetch('/api/' + endpoint, options);
                return await response.json();
            } catch (error) {
                console.error('API Error:', error);
                return null;
            }
        }

        // Player controls
        function playerControl(action) {
            apiCall('control.php', 'POST', { action: action });
        }

        // Quick actions
        function quickAction(action) {
            apiCall('system.php', 'POST', { action: action });
        }

        // System actions
        function systemAction(action) {
            if (confirm('Êtes-vous sûr ?')) {
                apiCall('system.php', 'POST', { action: action });
            }
        }

        // YouTube download
        function downloadYoutube() {
            const url = document.getElementById('youtube-url').value;
            const quality = document.getElementById('youtube-quality').value;

            if (url) {
                apiCall('youtube.php', 'POST', {
                    url: url,
                    quality: quality
                });
            }
        }

        // Update system info
        async function updateSystemInfo() {
            const info = await apiCall('system.php');
            if (info) {
                document.getElementById('cpu').textContent = info.cpu || '--';
                document.getElementById('ram').textContent = info.ram || '--';
                document.getElementById('temp').textContent = info.temperature || '--';
                document.getElementById('uptime').textContent = info.uptime || '--';
            }
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            updateSystemInfo();
            // Update every 5 seconds
            setInterval(updateSystemInfo, 5000);
        });
    </script>
</body>
</html>