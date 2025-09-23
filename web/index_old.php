<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v0.8.0 - Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        .header {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }

        .header h1 {
            color: white;
            text-align: center;
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }

        .nav-tabs {
            display: flex;
            gap: 10px;
            justify-content: center;
            flex-wrap: wrap;
        }

        .nav-tab {
            background: rgba(255, 255, 255, 0.2);
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            color: white;
            cursor: pointer;
            transition: all 0.3s ease;
            font-weight: 500;
        }

        .nav-tab:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }

        .nav-tab.active {
            background: rgba(255, 255, 255, 0.4);
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }

        .content {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.2);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.3);
        }

        .tab-content {
            display: none;
        }

        .tab-content.active {
            display: block;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }

        .card {
            background: rgba(255, 255, 255, 0.8);
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border: 1px solid rgba(0,0,0,0.1);
        }

        .card h3 {
            margin-bottom: 15px;
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 8px;
        }

        .stat-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .stat-item {
            background: linear-gradient(45deg, #f8f9fa, #e9ecef);
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #667eea;
        }

        .stat-value {
            font-size: 1.8em;
            font-weight: bold;
            color: #667eea;
        }

        .stat-label {
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }

        .btn {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 500;
            transition: all 0.3s ease;
            margin: 5px;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }

        .btn-danger {
            background: linear-gradient(45deg, #e74c3c, #c0392b);
        }

        .btn-success {
            background: linear-gradient(45deg, #27ae60, #2ecc71);
        }

        .input-group {
            margin-bottom: 15px;
        }

        .input-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
            color: #333;
        }

        .input-group input,
        .input-group select,
        .input-group textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s ease;
        }

        .input-group input:focus,
        .input-group select:focus,
        .input-group textarea:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }

        .media-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 15px;
        }

        .media-item {
            background: white;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }

        .media-item:hover {
            transform: translateY(-5px);
        }

        .media-thumbnail {
            width: 100%;
            height: 120px;
            background: #f8f9fa;
            border-radius: 8px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 3em;
            color: #667eea;
        }

        .playlist-builder {
            display: flex;
            gap: 20px;
            min-height: 400px;
        }

        .available-media,
        .playlist-items {
            flex: 1;
            background: #f8f9fa;
            border-radius: 8px;
            padding: 15px;
            border: 2px dashed #ddd;
        }

        .playlist-items {
            border-color: #667eea;
        }

        .draggable-item {
            background: white;
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 6px;
            cursor: move;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
        }

        .draggable-item:hover {
            transform: scale(1.02);
        }

        .player-controls {
            display: flex;
            gap: 10px;
            justify-content: center;
            margin-bottom: 20px;
        }

        .screenshot-container {
            text-align: center;
            margin-bottom: 20px;
        }

        .screenshot-img {
            max-width: 100%;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }

        .progress-bar {
            width: 100%;
            height: 20px;
            background: #f0f0f0;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(45deg, #667eea, #764ba2);
            width: 0%;
            transition: width 0.3s ease;
        }

        .alert {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 15px;
            border-left: 4px solid;
        }

        .alert-success {
            background: #d4edda;
            color: #155724;
            border-color: #27ae60;
        }

        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border-color: #e74c3c;
        }

        .alert-info {
            background: #d1ecf1;
            color: #0c5460;
            border-color: #667eea;
        }

        .scheduler-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }

        .scheduler-table th,
        .scheduler-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }

        .scheduler-table th {
            background: #f8f9fa;
            font-weight: 600;
        }

        .hidden {
            display: none !important;
        }

        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        @media (max-width: 768px) {
            .playlist-builder {
                flex-direction: column;
            }

            .nav-tabs {
                flex-direction: column;
            }

            .grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ PiSignage v0.8.0</h1>
            <div class="nav-tabs">
                <button class="nav-tab active" onclick="showTab('dashboard')">📊 Dashboard</button>
                <button class="nav-tab" onclick="showTab('media')">📁 Médias</button>
                <button class="nav-tab" onclick="showTab('playlist')">📝 Playlists</button>
                <button class="nav-tab" onclick="showTab('player')">▶️ Lecteur</button>
                <button class="nav-tab" onclick="showTab('youtube')">📺 YouTube</button>
                <button class="nav-tab" onclick="showTab('screenshot')">📸 Capture</button>
                <button class="nav-tab" onclick="showTab('scheduler')">⏰ Programmation</button>
                <button class="nav-tab" onclick="showTab('config')">⚙️ Configuration</button>
            </div>
        </div>

        <div class="content">
            <!-- Dashboard Tab -->
            <div id="dashboard-tab" class="tab-content active">
                <h2>📊 État du système</h2>
                <div class="grid">
                    <div class="card">
                        <h3>🖥️ Système</h3>
                        <div class="stat-grid">
                            <div class="stat-item">
                                <div class="stat-value" id="cpu-usage">--</div>
                                <div class="stat-label">CPU</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value" id="memory-usage">--</div>
                                <div class="stat-label">RAM</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value" id="temperature">--</div>
                                <div class="stat-label">Température</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-value" id="uptime">--</div>
                                <div class="stat-label">Uptime</div>
                            </div>
                        </div>
                    </div>

                    <div class="card">
                        <h3>🎵 Lecteur VLC</h3>
                        <div id="vlc-status">
                            <p><strong>État:</strong> <span id="vlc-state">Arrêté</span></p>
                            <p><strong>Fichier:</strong> <span id="vlc-file">Aucun</span></p>
                            <p><strong>Position:</strong> <span id="vlc-position">00:00</span></p>
                        </div>
                        <div class="player-controls">
                            <button class="btn btn-success" onclick="vlcControl('play')">▶️ Play</button>
                            <button class="btn" onclick="vlcControl('pause')">⏸️ Pause</button>
                            <button class="btn btn-danger" onclick="vlcControl('stop')">⏹️ Stop</button>
                            <button class="btn" onclick="takeQuickScreenshot('dashboard')">📸 Capture</button>
                        </div>
                    </div>
                </div>

                <div class="card">
                    <h3>📊 Statistiques rapides</h3>
                    <div class="stat-grid">
                        <div class="stat-item">
                            <div class="stat-value" id="media-count">--</div>
                            <div class="stat-label">Fichiers médias</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="playlist-count">--</div>
                            <div class="stat-label">Playlists</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="storage-usage">--</div>
                            <div class="stat-label">Stockage utilisé</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="last-screenshot">--</div>
                            <div class="stat-label">Dernière capture</div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Media Management Tab -->
            <div id="media-tab" class="tab-content">
                <h2>📁 Gestionnaire de médias</h2>

                <div class="card">
                    <h3>📤 Upload de fichiers</h3>
                    <div class="input-group">
                        <label for="media-upload">Sélectionner des fichiers (Images, Vidéos, Audio)</label>
                        <input type="file" id="media-upload" multiple accept="video/*,image/*,audio/*">
                    </div>
                    <button class="btn" onclick="uploadFiles()">📤 Uploader les fichiers</button>
                    <div id="upload-progress" class="hidden">
                        <div class="progress-bar">
                            <div class="progress-fill" id="upload-progress-bar"></div>
                        </div>
                        <p id="upload-status">Upload en cours...</p>
                    </div>
                </div>

                <div class="card">
                    <h3>📋 Liste des médias</h3>
                    <button class="btn" onclick="refreshMediaList()">🔄 Actualiser</button>
                    <div id="media-list" class="media-grid">
                        <!-- Media items will be loaded here -->
                    </div>
                </div>
            </div>

            <!-- Playlist Tab -->
            <div id="playlist-tab" class="tab-content">
                <h2>📝 Créateur de playlists</h2>

                <div class="card">
                    <h3>➕ Nouvelle playlist</h3>
                    <div class="input-group">
                        <label for="playlist-name">Nom de la playlist</label>
                        <input type="text" id="playlist-name" placeholder="Ma nouvelle playlist">
                    </div>

                    <div class="playlist-builder">
                        <div class="available-media">
                            <h4>📁 Médias disponibles</h4>
                            <div id="available-media-list">
                                <!-- Available media items -->
                            </div>
                        </div>

                        <div class="playlist-items">
                            <h4>📝 Playlist (glissez-déposez)</h4>
                            <div id="playlist-items-list">
                                <!-- Playlist items -->
                            </div>
                        </div>
                    </div>

                    <button class="btn" onclick="savePlaylist()">💾 Sauvegarder la playlist</button>
                </div>

                <div class="card">
                    <h3>📄 Playlists existantes</h3>
                    <button class="btn" onclick="refreshPlaylists()">🔄 Actualiser</button>
                    <div id="playlists-list">
                        <!-- Existing playlists -->
                    </div>
                </div>
            </div>

            <!-- Player Tab -->
            <div id="player-tab" class="tab-content">
                <h2>▶️ Contrôle du lecteur</h2>

                <div class="card">
                    <h3>🎮 Contrôles VLC</h3>
                    <div class="player-controls">
                        <button class="btn btn-success" onclick="vlcControl('play')">▶️ Play</button>
                        <button class="btn" onclick="vlcControl('pause')">⏸️ Pause</button>
                        <button class="btn btn-danger" onclick="vlcControl('stop')">⏹️ Stop</button>
                        <button class="btn" onclick="vlcControl('next')">⏭️ Suivant</button>
                        <button class="btn" onclick="vlcControl('previous')">⏮️ Précédent</button>
                        <button class="btn" onclick="takeQuickScreenshot('player')">📸 Capture</button>
                    </div>

                    <div class="input-group">
                        <label for="volume-control">Volume</label>
                        <input type="range" id="volume-control" min="0" max="100" value="50" onchange="setVolume(this.value)">
                    </div>
                </div>

                <div class="card">
                    <h3>📄 Lecture de playlist</h3>
                    <div class="input-group">
                        <label for="playlist-select">Sélectionner une playlist</label>
                        <select id="playlist-select">
                            <option value="">-- Choisir une playlist --</option>
                        </select>
                    </div>
                    <button class="btn" onclick="playPlaylist()">▶️ Lancer la playlist</button>
                </div>

                <div class="card">
                    <h3>🎬 Mode de lecture</h3>
                    <div class="input-group">
                        <label for="player-mode">Sélectionner le mode</label>
                        <select id="player-mode">
                            <option value="fullscreen">Plein écran</option>
                            <option value="windowed">Fenêtré</option>
                            <option value="with-rss">Avec bandeau RSS</option>
                        </select>
                    </div>
                    <button class="btn" onclick="applyPlayerSettings()">💾 Appliquer</button>
                </div>

                <div class="card">
                    <h3>📂 Lecture de fichier unique</h3>
                    <div class="input-group">
                        <label for="single-file-select">Sélectionner un fichier</label>
                        <select id="single-file-select">
                            <option value="">-- Choisir un fichier --</option>
                        </select>
                    </div>
                    <button class="btn" onclick="playSingleFile()">▶️ Lancer le fichier</button>
                </div>
            </div>

            <!-- YouTube Tab -->
            <div id="youtube-tab" class="tab-content">
                <h2>📺 Téléchargement YouTube</h2>

                <div class="card">
                    <h3>📥 Télécharger une vidéo</h3>
                    <div class="input-group">
                        <label for="youtube-url">URL YouTube</label>
                        <input type="url" id="youtube-url" placeholder="https://www.youtube.com/watch?v=...">
                    </div>

                    <div class="input-group">
                        <label for="download-quality">Qualité</label>
                        <select id="download-quality">
                            <option value="best">Meilleure qualité</option>
                            <option value="720p">720p</option>
                            <option value="480p">480p</option>
                            <option value="360p">360p</option>
                            <option value="worst">Plus petite taille</option>
                        </select>
                    </div>

                    <button class="btn" onclick="downloadYoutube()">📥 Télécharger</button>

                    <div id="download-progress" class="hidden">
                        <div class="progress-bar">
                            <div class="progress-fill" id="youtube-progress-bar"></div>
                        </div>
                        <p id="download-status">Téléchargement en cours...</p>
                    </div>
                </div>

                <div class="card">
                    <h3>📋 Historique des téléchargements</h3>
                    <div id="youtube-history">
                        <!-- Download history -->
                    </div>
                </div>
            </div>

            <!-- Screenshot Tab -->
            <div id="screenshot-tab" class="tab-content">
                <h2>📸 Capture d'écran</h2>

                <div class="card">
                    <h3>📷 Capture en temps réel</h3>
                    <div class="screenshot-container">
                        <img id="screenshot-display" class="screenshot-img" src="" alt="Capture d'écran" style="display: none;">
                        <p id="screenshot-placeholder">Aucune capture disponible</p>
                    </div>

                    <div style="text-align: center;">
                        <button class="btn" onclick="takeScreenshot()">📸 Prendre une capture</button>
                        <button class="btn" onclick="toggleAutoScreenshot()">🔄 Auto-capture (OFF)</button>
                    </div>

                    <div class="input-group">
                        <label for="auto-interval">Intervalle auto-capture (secondes)</label>
                        <input type="number" id="auto-interval" value="30" min="5" max="300">
                    </div>
                </div>

                <div class="card">
                    <h3>📋 Historique des captures</h3>
                    <div id="screenshot-history">
                        <!-- Screenshot history -->
                    </div>
                </div>
            </div>

            <!-- Scheduler Tab -->
            <div id="scheduler-tab" class="tab-content">
                <h2>⏰ Programmation horaire</h2>

                <div class="card">
                    <h3>➕ Nouveau programme</h3>
                    <div class="input-group">
                        <label for="schedule-name">Nom du programme</label>
                        <input type="text" id="schedule-name" placeholder="Programme du matin">
                    </div>

                    <div class="input-group">
                        <label for="schedule-playlist">Playlist</label>
                        <select id="schedule-playlist">
                            <option value="">-- Choisir une playlist --</option>
                        </select>
                    </div>

                    <div class="input-group">
                        <label for="schedule-start">Heure de début</label>
                        <input type="time" id="schedule-start">
                    </div>

                    <div class="input-group">
                        <label for="schedule-end">Heure de fin</label>
                        <input type="time" id="schedule-end">
                    </div>

                    <div class="input-group">
                        <label for="schedule-days">Jours de la semaine</label>
                        <div style="display: flex; flex-wrap: wrap; gap: 10px;">
                            <label><input type="checkbox" value="1"> Lundi</label>
                            <label><input type="checkbox" value="2"> Mardi</label>
                            <label><input type="checkbox" value="3"> Mercredi</label>
                            <label><input type="checkbox" value="4"> Jeudi</label>
                            <label><input type="checkbox" value="5"> Vendredi</label>
                            <label><input type="checkbox" value="6"> Samedi</label>
                            <label><input type="checkbox" value="0"> Dimanche</label>
                        </div>
                    </div>

                    <button class="btn" onclick="saveSchedule()">💾 Sauvegarder le programme</button>
                </div>

                <div class="card">
                    <h3>📅 Programmes actifs</h3>
                    <button class="btn" onclick="refreshSchedules()">🔄 Actualiser</button>
                    <table class="scheduler-table">
                        <thead>
                            <tr>
                                <th>Nom</th>
                                <th>Playlist</th>
                                <th>Horaire</th>
                                <th>Jours</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody id="schedules-list">
                            <!-- Schedules will be loaded here -->
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Configuration Tab -->
            <div id="config-tab" class="tab-content">
                <h2>⚙️ Configuration système</h2>

                <div class="grid">
                    <div class="card">
                        <h3>🖥️ Affichage</h3>
                        <div class="input-group">
                            <label for="resolution">Résolution</label>
                            <select id="resolution">
                                <option value="1920x1080">1920x1080 (Full HD)</option>
                                <option value="1280x720">1280x720 (HD)</option>
                                <option value="1024x768">1024x768</option>
                                <option value="800x600">800x600</option>
                            </select>
                        </div>

                        <div class="input-group">
                            <label for="rotation">Rotation de l'écran</label>
                            <select id="rotation">
                                <option value="0">0° (Normal)</option>
                                <option value="90">90° (Droite)</option>
                                <option value="180">180° (Inversé)</option>
                                <option value="270">270° (Gauche)</option>
                            </select>
                        </div>

                        <button class="btn" onclick="saveDisplayConfig()">💾 Appliquer</button>
                    </div>

                    <div class="card">
                        <h3>🔊 Audio</h3>
                        <div class="input-group">
                            <label for="audio-output">Sortie audio</label>
                            <select id="audio-output">
                                <option value="auto">Automatique</option>
                                <option value="hdmi">HDMI</option>
                                <option value="jack">Jack 3.5mm</option>
                                <option value="usb">USB</option>
                            </select>
                        </div>

                        <div class="input-group">
                            <label for="default-volume">Volume par défaut</label>
                            <input type="range" id="default-volume" min="0" max="100" value="50">
                            <span id="volume-display">50%</span>
                        </div>

                        <button class="btn" onclick="saveAudioConfig()">💾 Appliquer</button>
                    </div>
                </div>

                <div class="card">
                    <h3>🌐 Réseau</h3>
                    <div class="input-group">
                        <label for="hostname">Nom d'hôte</label>
                        <input type="text" id="hostname" placeholder="pisignage">
                    </div>

                    <div class="input-group">
                        <label for="timezone">Fuseau horaire</label>
                        <select id="timezone">
                            <option value="Europe/Paris">Europe/Paris</option>
                            <option value="Europe/London">Europe/London</option>
                            <option value="America/New_York">America/New_York</option>
                            <option value="America/Los_Angeles">America/Los_Angeles</option>
                        </select>
                    </div>

                    <button class="btn" onclick="saveNetworkConfig()">💾 Appliquer</button>
                </div>

                <div class="card">
                    <h3>🔧 Actions système</h3>
                    <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                        <button class="btn btn-danger" onclick="systemAction('reboot')">🔄 Redémarrer</button>
                        <button class="btn btn-danger" onclick="systemAction('shutdown')">⚡ Éteindre</button>
                        <button class="btn" onclick="systemAction('restart-vlc')">🎵 Redémarrer VLC</button>
                        <button class="btn" onclick="systemAction('clear-cache')">🗑️ Vider le cache</button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Global variables
        let autoScreenshotInterval = null;
        let systemStatsInterval = null;

        // Essential functions for Puppeteer tests
        function switchTab(tabName) {
            const tabs = document.querySelectorAll('.tab');
            const contents = document.querySelectorAll('.tab-content');

            tabs.forEach(tab => {
                if (tab.id === tabName + '-tab') {
                    tab.classList.add('active');
                } else {
                    tab.classList.remove('active');
                }
            });

            contents.forEach(content => {
                if (content.id === tabName + '-content') {
                    content.style.display = 'block';
                } else {
                    content.style.display = 'none';
                }
            });
        }

        async function refreshDashboard() {
            try {
                const response = await fetch('/api/system.php');
                const data = await response.json();

                if (data.success) {
                    document.getElementById('cpu-usage').innerText = data.data.cpu + '%';
                    document.getElementById('memory-usage').innerText = data.data.memory + '%';
                    document.getElementById('temperature').innerText = data.data.temperature + '°C';
                    document.getElementById('uptime').innerText = data.data.uptime;
                }
            } catch (error) {
                console.error('Dashboard refresh error:', error);
            }
        }

        // Initialize the application
        document.addEventListener('DOMContentLoaded', function() {
            loadSystemStats();
            refreshMediaList();
            refreshPlaylists();
            loadPlaylaysForSelects();
            startSystemMonitoring();
        });

        // Tab management
        function showTab(tabName) {
            // Hide all tab contents
            document.querySelectorAll('.tab-content').forEach(tab => {
                tab.classList.remove('active');
            });

            // Remove active class from all nav tabs
            document.querySelectorAll('.nav-tab').forEach(tab => {
                tab.classList.remove('active');
            });

            // Show selected tab content
            document.getElementById(tabName + '-tab').classList.add('active');

            // Add active class to selected nav tab
            event.target.classList.add('active');
        }

        // System monitoring
        function startSystemMonitoring() {
            systemStatsInterval = setInterval(loadSystemStats, 5000);
        }

        function loadSystemStats() {
            fetch('/api/system.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('cpu-usage').textContent = data.data.cpu + '%';
                        document.getElementById('memory-usage').textContent = data.data.memory + '%';
                        document.getElementById('temperature').textContent = data.data.temperature + '°C';
                        document.getElementById('uptime').textContent = data.data.uptime;
                        document.getElementById('media-count').textContent = data.data.media_count;
                        document.getElementById('storage-usage').textContent = data.data.storage;
                    }
                })
                .catch(error => console.error('Error loading system stats:', error));
        }

        // Media management
        function refreshMediaList() {
            fetch('/api/media.php?action=list')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        displayMediaList(data.data);
                        updateAvailableMediaList(data.data);
                    }
                })
                .catch(error => console.error('Error loading media list:', error));
        }

        function displayMediaList(mediaFiles) {
            const mediaList = document.getElementById('media-list');
            mediaList.innerHTML = '';

            mediaFiles.forEach(file => {
                const mediaItem = document.createElement('div');
                mediaItem.className = 'media-item';

                const icon = getFileIcon(file.type);
                const size = formatFileSize(file.size);

                mediaItem.innerHTML = `
                    <div class="media-thumbnail">${icon}</div>
                    <h4>${file.name}</h4>
                    <p>${file.type} - ${size}</p>
                    <button class="btn btn-danger" onclick="deleteMedia('${file.name}')">🗑️ Supprimer</button>
                `;

                mediaList.appendChild(mediaItem);
            });
        }

        function uploadFiles() {
            const fileInput = document.getElementById('media-upload');
            const files = fileInput.files;

            if (files.length === 0) {
                showAlert('Veuillez sélectionner au moins un fichier.', 'error');
                return;
            }

            const formData = new FormData();
            for (let i = 0; i < files.length; i++) {
                formData.append('files[]', files[i]);
            }

            document.getElementById('upload-progress').classList.remove('hidden');

            fetch('/api/upload.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('upload-progress').classList.add('hidden');

                if (data.success) {
                    showAlert('Fichiers uploadés avec succès!', 'success');
                    refreshMediaList();
                    fileInput.value = '';
                } else {
                    showAlert('Erreur lors de l\'upload: ' + data.message, 'error');
                }
            })
            .catch(error => {
                document.getElementById('upload-progress').classList.add('hidden');
                showAlert('Erreur lors de l\'upload.', 'error');
            });
        }

        function deleteMedia(filename) {
            if (!confirm('Êtes-vous sûr de vouloir supprimer ce fichier?')) {
                return;
            }

            fetch('/api/media.php', {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ filename: filename })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Fichier supprimé avec succès!', 'success');
                    refreshMediaList();
                } else {
                    showAlert('Erreur lors de la suppression: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur lors de la suppression.', 'error'));
        }

        // Playlist management
        function updateAvailableMediaList(mediaFiles) {
            const availableList = document.getElementById('available-media-list');
            availableList.innerHTML = '';

            mediaFiles.forEach(file => {
                const item = document.createElement('div');
                item.className = 'draggable-item';
                item.draggable = true;
                item.dataset.filename = file.name;
                item.innerHTML = `${getFileIcon(file.type)} ${file.name}`;

                item.addEventListener('dragstart', function(e) {
                    e.dataTransfer.setData('text/plain', file.name);
                });

                availableList.appendChild(item);
            });
        }

        function refreshPlaylists() {
            fetch('/api/playlist.php?action=list')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        displayPlaylistsList(data.data);
                    }
                })
                .catch(error => console.error('Error loading playlists:', error));
        }

        function displayPlaylistsList(playlists) {
            const playlistsList = document.getElementById('playlists-list');
            playlistsList.innerHTML = '';

            playlists.forEach(playlist => {
                const playlistItem = document.createElement('div');
                playlistItem.className = 'card';
                playlistItem.innerHTML = `
                    <h4>${playlist.name}</h4>
                    <p>${playlist.items.length} éléments</p>
                    <button class="btn" onclick="loadPlaylist('${playlist.name}')">📝 Modifier</button>
                    <button class="btn btn-success" onclick="playPlaylistByName('${playlist.name}')">▶️ Jouer</button>
                    <button class="btn btn-danger" onclick="deletePlaylist('${playlist.name}')">🗑️ Supprimer</button>
                `;

                playlistsList.appendChild(playlistItem);
            });
        }

        function savePlaylist() {
            const name = document.getElementById('playlist-name').value.trim();
            const items = Array.from(document.getElementById('playlist-items-list').children)
                .map(item => item.dataset.filename);

            if (!name) {
                showAlert('Veuillez donner un nom à la playlist.', 'error');
                return;
            }

            if (items.length === 0) {
                showAlert('Veuillez ajouter au moins un élément à la playlist.', 'error');
                return;
            }

            fetch('/api/playlist.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'save',
                    name: name,
                    items: items
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist sauvegardée avec succès!', 'success');
                    document.getElementById('playlist-name').value = '';
                    document.getElementById('playlist-items-list').innerHTML = '';
                    refreshPlaylists();
                    loadPlaylaysForSelects();
                } else {
                    showAlert('Erreur lors de la sauvegarde: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur lors de la sauvegarde.', 'error'));
        }

        // Player controls
        function vlcControl(action) {
            fetch('/api/player.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ action: action })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Action ${action} exécutée avec succès!`, 'success');
                    updateVLCStatus();
                } else {
                    showAlert(`Erreur lors de l'action ${action}: ` + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de communication avec VLC.', 'error'));
        }

        function setVolume(volume) {
            fetch('/api/player.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'volume',
                    value: volume
                })
            })
            .then(response => response.json())
            .then(data => {
                if (!data.success) {
                    showAlert('Erreur lors du réglage du volume.', 'error');
                }
            })
            .catch(error => console.error('Volume control error:', error));
        }

        function playPlaylist() {
            const playlistName = document.getElementById('playlist-select').value;
            if (!playlistName) {
                showAlert('Veuillez sélectionner une playlist.', 'error');
                return;
            }

            fetch('/api/player.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'play_playlist',
                    playlist: playlistName
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist lancée avec succès!', 'success');
                } else {
                    showAlert('Erreur lors du lancement: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur lors du lancement.', 'error'));
        }

        // Single file playback
        function playSingleFile() {
            const fileName = document.getElementById('single-file-select').value;
            if (!fileName) {
                showAlert('Veuillez sélectionner un fichier.', 'error');
                return;
            }

            fetch('/api/player.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'play-file',
                    file: fileName
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Lecture du fichier démarrée!', 'success');
                    updateVLCStatus();
                } else {
                    showAlert('Erreur lors de la lecture: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de communication avec le lecteur.', 'error'));
        }

        // Player mode settings
        function applyPlayerSettings() {
            const mode = document.getElementById('player-mode').value;

            fetch('/api/player.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'set-mode',
                    mode: mode
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Mode ${mode} appliqué avec succès!`, 'success');
                    updateVLCStatus();
                } else {
                    showAlert('Erreur lors du changement de mode: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de communication avec le lecteur.', 'error'));
        }

        // Quick screenshot function for dashboard and player
        function takeQuickScreenshot(source) {
            showAlert(`Capture d'écran depuis ${source}...`, 'info');

            fetch('/api/screenshot-simple.php?action=capture')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Show a modal with the screenshot
                    const modal = document.createElement('div');
                    modal.className = 'modal';
                    modal.style.cssText = `
                        position: fixed;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                        background: rgba(0,0,0,0.8);
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        z-index: 10000;
                        cursor: pointer;
                    `;

                    const img = document.createElement('img');
                    img.src = data.data.url + '?' + Date.now();
                    img.style.cssText = `
                        max-width: 90%;
                        max-height: 90%;
                        border-radius: 10px;
                        box-shadow: 0 4px 20px rgba(0,0,0,0.5);
                    `;

                    modal.appendChild(img);
                    modal.onclick = () => document.body.removeChild(modal);
                    document.body.appendChild(modal);

                    showAlert('Capture réalisée avec succès!', 'success');
                } else {
                    showAlert('Erreur lors de la capture: ' + data.message, 'error');
                }
            })
            .catch(error => {
                console.error('Erreur:', error);
                showAlert('Erreur lors de la capture d\'écran.', 'error');
            });
        }

        // YouTube download
        function downloadYoutube() {
            const url = document.getElementById('youtube-url').value.trim();
            const quality = document.getElementById('download-quality').value;

            if (!url) {
                showAlert('Veuillez entrer une URL YouTube.', 'error');
                return;
            }

            document.getElementById('download-progress').classList.remove('hidden');

            fetch('/api/youtube.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    url: url,
                    quality: quality
                })
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('download-progress').classList.add('hidden');

                if (data.success) {
                    showAlert('Vidéo téléchargée avec succès!', 'success');
                    document.getElementById('youtube-url').value = '';
                    refreshMediaList();
                } else {
                    showAlert('Erreur lors du téléchargement: ' + data.message, 'error');
                }
            })
            .catch(error => {
                document.getElementById('download-progress').classList.add('hidden');
                showAlert('Erreur lors du téléchargement.', 'error');
            });
        }

        // Screenshot
        function takeScreenshot() {
            showAlert('Capture en cours...', 'info');
            fetch('/api/screenshot-simple.php?action=capture')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    displayScreenshot(data.data.url);
                    showAlert('Capture réalisée avec succès!', 'success');
                    // Mettre à jour le timestamp
                    document.getElementById('last-screenshot').textContent = new Date().toLocaleTimeString();
                } else {
                    showAlert('Erreur lors de la capture: ' + data.message, 'error');
                }
            })
            .catch(error => {
                console.error('Erreur:', error);
                showAlert('Erreur lors de la capture.', 'error');
            });
        }

        function displayScreenshot(url) {
            const img = document.getElementById('screenshot-display');
            const placeholder = document.getElementById('screenshot-placeholder');

            img.src = url + '?t=' + Date.now();
            img.style.display = 'block';
            placeholder.style.display = 'none';
        }

        function toggleAutoScreenshot() {
            const button = event.target;

            if (autoScreenshotInterval) {
                clearInterval(autoScreenshotInterval);
                autoScreenshotInterval = null;
                button.textContent = '🔄 Auto-capture (OFF)';
                showAlert('Auto-capture désactivée.', 'info');
            } else {
                const interval = parseInt(document.getElementById('auto-interval').value) * 1000;
                autoScreenshotInterval = setInterval(takeScreenshot, interval);
                button.textContent = '🔄 Auto-capture (ON)';
                showAlert('Auto-capture activée.', 'success');
            }
        }

        // Utility functions
        function getFileIcon(type) {
            if (type.startsWith('video/')) return '🎬';
            if (type.startsWith('image/')) return '🖼️';
            if (type.startsWith('audio/')) return '🎵';
            return '📄';
        }

        function formatFileSize(bytes) {
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            if (bytes === 0) return '0 Bytes';
            const i = Math.floor(Math.log(bytes) / Math.log(1024));
            return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
        }

        function showAlert(message, type) {
            const alertDiv = document.createElement('div');
            alertDiv.className = `alert alert-${type}`;
            alertDiv.textContent = message;

            document.body.insertBefore(alertDiv, document.body.firstChild);

            setTimeout(() => {
                alertDiv.remove();
            }, 5000);
        }

        function loadPlaylaysForSelects() {
            fetch('/api/playlist.php?action=list')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const selects = ['playlist-select', 'schedule-playlist'];
                        selects.forEach(selectId => {
                            const select = document.getElementById(selectId);
                            select.innerHTML = '<option value="">-- Choisir une playlist --</option>';

                            data.data.forEach(playlist => {
                                const option = document.createElement('option');
                                option.value = playlist.name;
                                option.textContent = playlist.name;
                                select.appendChild(option);
                            });
                        });
                    }
                })
                .catch(error => console.error('Error loading playlists for selects:', error));
        }

        // Drag and drop for playlist builder
        document.addEventListener('DOMContentLoaded', function() {
            const playlistItemsList = document.getElementById('playlist-items-list');

            playlistItemsList.addEventListener('dragover', function(e) {
                e.preventDefault();
            });

            playlistItemsList.addEventListener('drop', function(e) {
                e.preventDefault();
                const filename = e.dataTransfer.getData('text/plain');

                const item = document.createElement('div');
                item.className = 'draggable-item';
                item.dataset.filename = filename;
                item.innerHTML = `📄 ${filename} <button onclick="this.parentElement.remove()" style="float: right; background: red; color: white; border: none; border-radius: 3px;">✕</button>`;

                playlistItemsList.appendChild(item);
            });
        });

        // Configuration functions
        function saveDisplayConfig() {
            const resolution = document.getElementById('resolution').value;
            const rotation = document.getElementById('rotation').value;

            fetch('/api/system.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'config',
                    type: 'display',
                    resolution: resolution,
                    rotation: rotation
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Configuration d\'affichage sauvegardée!', 'success');
                } else {
                    showAlert('Erreur lors de la sauvegarde.', 'error');
                }
            })
            .catch(error => showAlert('Erreur lors de la sauvegarde.', 'error'));
        }

        function saveAudioConfig() {
            const output = document.getElementById('audio-output').value;
            const volume = document.getElementById('default-volume').value;

            fetch('/api/system.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: 'config',
                    type: 'audio',
                    output: output,
                    volume: volume
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Configuration audio sauvegardée!', 'success');
                } else {
                    showAlert('Erreur lors de la sauvegarde.', 'error');
                }
            })
            .catch(error => showAlert('Erreur lors de la sauvegarde.', 'error'));
        }

        function systemAction(action) {
            if (['reboot', 'shutdown'].includes(action)) {
                if (!confirm(`Êtes-vous sûr de vouloir ${action === 'reboot' ? 'redémarrer' : 'éteindre'} le système?`)) {
                    return;
                }
            }

            fetch('/api/system.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ action: action })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Action ${action} exécutée avec succès!`, 'success');
                } else {
                    showAlert('Erreur lors de l\'exécution.', 'error');
                }
            })
            .catch(error => showAlert('Erreur lors de l\'exécution.', 'error'));
        }

        // Update volume display
        document.getElementById('default-volume').addEventListener('input', function() {
            document.getElementById('volume-display').textContent = this.value + '%';
        });
    </script>
</body>
</html>