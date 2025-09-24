<?php
session_start();

// Configuration
$config = [
    'version' => '0.8.0',
    'media_path' => '/opt/pisignage/media/',
    'config_path' => '/opt/pisignage/config/',
    'logs_path' => '/opt/pisignage/logs/',
    'upload_max_size' => 500 * 1024 * 1024, // 500MB
];

// Ensure directories exist
$dirs = [$config['media_path'], $config['config_path'], $config['logs_path']];
foreach ($dirs as $dir) {
    if (!file_exists($dir)) {
        mkdir($dir, 0755, true);
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PiSignage v<?= $config['version'] ?> - Interface de Gestion</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --primary: #4a9eff;
            --secondary: #ff6b6b;
            --success: #51cf66;
            --warning: #ffd43b;
            --danger: #ff6b6b;
            --dark: #1a1a2e;
            --dark-light: #16213e;
            --light: #f0f3f7;
            --glass: rgba(255, 255, 255, 0.05);
            --glass-border: rgba(255, 255, 255, 0.1);
        }

        body {
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            color: var(--light);
            min-height: 100vh;
            display: flex;
            overflow-x: hidden;
        }

        /* Glassmorphism Effects */
        .glass {
            background: var(--glass);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border: 1px solid var(--glass-border);
            border-radius: 15px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }

        /* Sidebar */
        .sidebar {
            width: 280px;
            height: 100vh;
            background: rgba(26, 26, 46, 0.95);
            backdrop-filter: blur(20px);
            border-right: 1px solid var(--glass-border);
            padding: 30px 20px;
            position: fixed;
            left: 0;
            top: 0;
            overflow-y: auto;
            z-index: 1000;
            transition: transform 0.3s ease;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 15px;
            margin-bottom: 50px;
            padding: 15px;
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            border-radius: 15px;
            font-size: 24px;
            font-weight: bold;
            letter-spacing: 1px;
            text-align: center;
            justify-content: center;
            box-shadow: 0 10px 25px rgba(74, 158, 255, 0.3);
        }

        .logo-version {
            font-size: 12px;
            opacity: 0.8;
            display: block;
            margin-top: 5px;
        }

        .nav-section {
            margin-bottom: 30px;
        }

        .nav-title {
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 1px;
            text-transform: uppercase;
            color: rgba(240, 243, 247, 0.5);
            margin-bottom: 15px;
            padding-left: 10px;
        }

        .nav-item {
            display: flex;
            align-items: center;
            gap: 15px;
            padding: 14px 16px;
            margin-bottom: 8px;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            font-size: 15px;
            color: rgba(240, 243, 247, 0.8);
        }

        .nav-item:hover {
            background: rgba(74, 158, 255, 0.1);
            color: var(--light);
            transform: translateX(5px);
        }

        .nav-item.active {
            background: linear-gradient(135deg, rgba(74, 158, 255, 0.2), rgba(74, 158, 255, 0.1));
            color: var(--primary);
            border-left: 3px solid var(--primary);
        }

        .nav-item.active::after {
            content: '';
            position: absolute;
            right: 20px;
            width: 8px;
            height: 8px;
            background: var(--primary);
            border-radius: 50%;
            box-shadow: 0 0 10px var(--primary);
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.5; transform: scale(1.1); }
            100% { opacity: 1; transform: scale(1); }
        }

        /* Main Content */
        .main-content {
            flex: 1;
            margin-left: 280px;
            padding: 30px;
            position: relative;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 30px;
            padding: 20px 30px;
            background: var(--glass);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            border: 1px solid var(--glass-border);
        }

        .page-title {
            font-size: 32px;
            font-weight: 600;
            background: linear-gradient(135deg, var(--primary), #ff6b6b);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .header-actions {
            display: flex;
            gap: 15px;
        }

        /* Content Sections */
        .content-section {
            display: none;
            animation: fadeIn 0.5s ease;
        }

        .content-section.active {
            display: block;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* Cards */
        .card {
            background: var(--glass);
            backdrop-filter: blur(10px);
            border: 1px solid var(--glass-border);
            border-radius: 20px;
            padding: 25px;
            margin-bottom: 25px;
            transition: all 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(74, 158, 255, 0.2);
            border-color: rgba(74, 158, 255, 0.3);
        }

        .card-title {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        /* Grid Layout */
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }

        .grid-2 {
            grid-template-columns: repeat(2, 1fr);
        }

        .grid-3 {
            grid-template-columns: repeat(3, 1fr);
        }

        /* Stats Cards */
        .stat-card {
            background: linear-gradient(135deg, var(--glass), rgba(74, 158, 255, 0.1));
            padding: 20px;
            border-radius: 15px;
            border: 1px solid var(--glass-border);
            text-align: center;
            transition: all 0.3s ease;
        }

        .stat-card:hover {
            transform: scale(1.05);
            box-shadow: 0 10px 30px rgba(74, 158, 255, 0.3);
        }

        .stat-value {
            font-size: 36px;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 5px;
        }

        .stat-label {
            font-size: 14px;
            color: rgba(240, 243, 247, 0.6);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        /* Buttons */
        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .btn-primary {
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            color: white;
            box-shadow: 0 5px 15px rgba(74, 158, 255, 0.3);
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 7px 20px rgba(74, 158, 255, 0.4);
        }

        .btn-success {
            background: linear-gradient(135deg, var(--success), #42c056);
            color: white;
            box-shadow: 0 5px 15px rgba(81, 207, 102, 0.3);
        }

        .btn-danger {
            background: linear-gradient(135deg, var(--danger), #ff5252);
            color: white;
            box-shadow: 0 5px 15px rgba(255, 107, 107, 0.3);
        }

        .btn-glass {
            background: var(--glass);
            color: var(--light);
            border: 1px solid var(--glass-border);
            backdrop-filter: blur(10px);
        }

        .btn-glass:hover {
            background: rgba(74, 158, 255, 0.2);
            border-color: var(--primary);
        }

        /* Forms */
        .form-group {
            margin-bottom: 20px;
        }

        .form-label {
            display: block;
            margin-bottom: 8px;
            font-size: 14px;
            font-weight: 500;
            color: rgba(240, 243, 247, 0.8);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .form-control {
            width: 100%;
            padding: 12px 16px;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--glass-border);
            border-radius: 10px;
            color: var(--light);
            font-size: 15px;
            transition: all 0.3s ease;
        }

        .form-control:focus {
            outline: none;
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.1);
            box-shadow: 0 0 20px rgba(74, 158, 255, 0.2);
        }

        /* Player Controls */
        .player-controls {
            display: flex;
            gap: 15px;
            justify-content: center;
            margin: 20px 0;
        }

        .player-btn {
            width: 60px;
            height: 60px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            background: var(--glass);
            border: 2px solid var(--glass-border);
            color: var(--light);
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .player-btn:hover {
            transform: scale(1.1);
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.2);
        }

        .player-btn.active {
            background: linear-gradient(135deg, var(--primary), #3d7edb);
            border-color: var(--primary);
        }

        /* Upload Zone */
        .upload-zone {
            border: 2px dashed var(--glass-border);
            border-radius: 15px;
            padding: 40px;
            text-align: center;
            background: var(--glass);
            transition: all 0.3s ease;
            cursor: pointer;
        }

        .upload-zone:hover {
            border-color: var(--primary);
            background: rgba(74, 158, 255, 0.1);
        }

        .upload-zone.dragging {
            border-color: var(--success);
            background: rgba(81, 207, 102, 0.1);
        }

        /* Alert Messages */
        .alert {
            padding: 15px 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
            animation: slideIn 0.3s ease;
        }

        @keyframes slideIn {
            from { transform: translateX(-100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }

        .alert-success {
            background: rgba(81, 207, 102, 0.2);
            border: 1px solid rgba(81, 207, 102, 0.4);
            color: var(--success);
        }

        .alert-error {
            background: rgba(255, 107, 107, 0.2);
            border: 1px solid rgba(255, 107, 107, 0.4);
            color: var(--danger);
        }

        .alert-info {
            background: rgba(74, 158, 255, 0.2);
            border: 1px solid rgba(74, 158, 255, 0.4);
            color: var(--primary);
        }

        /* Responsive */
        .menu-toggle {
            display: none;
            position: fixed;
            top: 20px;
            left: 20px;
            z-index: 1001;
            background: var(--glass);
            padding: 10px;
            border-radius: 10px;
            cursor: pointer;
        }

        @media (max-width: 768px) {
            .menu-toggle {
                display: block;
            }

            .sidebar {
                transform: translateX(-100%);
            }

            .sidebar.active {
                transform: translateX(0);
            }

            .main-content {
                margin-left: 0;
            }

            .grid {
                grid-template-columns: 1fr;
            }
        }

        /* Scrollbar Styling */
        ::-webkit-scrollbar {
            width: 10px;
            height: 10px;
        }

        ::-webkit-scrollbar-track {
            background: var(--dark);
            border-radius: 10px;
        }

        ::-webkit-scrollbar-thumb {
            background: var(--primary);
            border-radius: 10px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: #3d7edb;
        }

        /* Loading Spinner */
        .spinner {
            border: 3px solid var(--glass-border);
            border-top: 3px solid var(--primary);
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        /* Modal */
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.8);
            z-index: 2000;
            justify-content: center;
            align-items: center;
            backdrop-filter: blur(5px);
        }

        .modal.active {
            display: flex;
        }

        .modal-content {
            background: var(--dark);
            padding: 30px;
            border-radius: 20px;
            border: 1px solid var(--glass-border);
            max-width: 600px;
            width: 90%;
            max-height: 80vh;
            overflow-y: auto;
            animation: modalSlideIn 0.3s ease;
        }

        @keyframes modalSlideIn {
            from {
                transform: translateY(-50px);
                opacity: 0;
            }
            to {
                transform: translateY(0);
                opacity: 1;
            }
        }

        /* Progress Bar */
        .progress-bar {
            width: 100%;
            height: 8px;
            background: var(--glass);
            border-radius: 10px;
            overflow: hidden;
            margin: 15px 0;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, var(--primary), var(--success));
            border-radius: 10px;
            transition: width 0.3s ease;
            animation: progressPulse 2s ease infinite;
        }

        @keyframes progressPulse {
            0% { opacity: 1; }
            50% { opacity: 0.8; }
            100% { opacity: 1; }
        }

        /* Screenshot Preview */
        .screenshot-preview {
            position: relative;
            border-radius: 15px;
            overflow: hidden;
            background: var(--glass);
            border: 1px solid var(--glass-border);
            margin: 20px 0;
        }

        .screenshot-preview img {
            width: 100%;
            height: auto;
            display: block;
        }

        .screenshot-overlay {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(180deg, transparent, rgba(0, 0, 0, 0.7));
            display: flex;
            align-items: flex-end;
            padding: 20px;
            opacity: 0;
            transition: opacity 0.3s ease;
        }

        .screenshot-preview:hover .screenshot-overlay {
            opacity: 1;
        }

        /* Tab Navigation */
        .tab-nav {
            display: flex;
            gap: 10px;
            margin-bottom: 25px;
            border-bottom: 1px solid var(--glass-border);
            padding-bottom: 15px;
        }

        .tab-btn {
            padding: 10px 20px;
            background: transparent;
            border: none;
            color: rgba(240, 243, 247, 0.6);
            cursor: pointer;
            font-size: 15px;
            font-weight: 500;
            transition: all 0.3s ease;
            position: relative;
        }

        .tab-btn:hover {
            color: var(--light);
        }

        .tab-btn.active {
            color: var(--primary);
        }

        .tab-btn.active::after {
            content: '';
            position: absolute;
            bottom: -16px;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, var(--primary), transparent);
            border-radius: 3px;
        }

        /* Empty State */
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: rgba(240, 243, 247, 0.4);
        }

        .empty-state-icon {
            font-size: 64px;
            margin-bottom: 20px;
            opacity: 0.5;
        }

        .empty-state-title {
            font-size: 20px;
            margin-bottom: 10px;
        }

        .empty-state-text {
            font-size: 14px;
        }
    </style>
    <script src="functions.js" defer></script>
</head>
<body>
    <!-- Menu Toggle (Mobile) -->
    <div class="menu-toggle" onclick="toggleSidebar()">
        <svg width="24" height="24" fill="currentColor">
            <path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
        </svg>
    </div>

    <!-- Sidebar -->
    <div class="sidebar" id="sidebar">
        <div class="logo">
            <div>
                🖥️ PiSignage
                <span class="logo-version">v<?= $config['version'] ?></span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Principal</div>
            <div class="nav-item active" onclick="showSection('dashboard')">
                <span>📊</span>
                <span>Dashboard</span>
            </div>
            <div class="nav-item" onclick="showSection('media')">
                <span>📁</span>
                <span>Médias</span>
            </div>
            <div class="nav-item" onclick="showSection('playlists')">
                <span>🎵</span>
                <span>Playlists</span>
            </div>
            <div class="nav-item" onclick="showSection('youtube')">
                <span>📺</span>
                <span>YouTube</span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Contrôle</div>
            <div class="nav-item" onclick="showSection('player')">
                <span>▶️</span>
                <span>Lecteur</span>
            </div>
            <div class="nav-item" onclick="showSection('schedule')">
                <span>📅</span>
                <span>Programmation</span>
            </div>
            <div class="nav-item" onclick="showSection('screenshot')">
                <span>📸</span>
                <span>Capture</span>
            </div>
        </div>

        <div class="nav-section">
            <div class="nav-title">Système</div>
            <div class="nav-item" onclick="showSection('settings')">
                <span>⚙️</span>
                <span>Paramètres</span>
            </div>
            <div class="nav-item" onclick="showSection('logs')">
                <span>📋</span>
                <span>Logs</span>
            </div>
        </div>
    </div>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Dashboard Section -->
        <div id="dashboard" class="content-section active">
            <div class="header">
                <h1 class="page-title">Dashboard</h1>
                <div class="header-actions">
                    <button class="btn btn-glass" onclick="takeQuickScreenshot('dashboard')">
                        📸 Capture
                    </button>
                    <button class="btn btn-primary" onclick="refreshStats()">
                        🔄 Actualiser
                    </button>
                </div>
            </div>

            <div class="grid grid-3">
                <div class="stat-card">
                    <div class="stat-value" id="cpu-usage">--</div>
                    <div class="stat-label">CPU</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="ram-usage">--</div>
                    <div class="stat-label">RAM</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value" id="temperature">--</div>
                    <div class="stat-label">Température</div>
                </div>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🎵</span>
                        Lecteur VLC
                    </h3>
                    <div id="vlc-status">
                        <p><strong>État:</strong> <span id="vlc-state">Arrêté</span></p>
                        <p><strong>Fichier:</strong> <span id="vlc-file">Aucun</span></p>
                        <p><strong>Position:</strong> <span id="vlc-position">00:00</span></p>
                    </div>
                    <div class="player-controls">
                        <div class="player-btn" onclick="vlcControl('play')">▶️</div>
                        <div class="player-btn" onclick="vlcControl('pause')">⏸️</div>
                        <div class="player-btn" onclick="vlcControl('stop')">⏹️</div>
                        <div class="player-btn" onclick="takeQuickScreenshot('player')">📸</div>
                    </div>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>📊</span>
                        Statistiques Système
                    </h3>
                    <div id="system-stats">
                        <p><strong>Uptime:</strong> <span id="uptime">--</span></p>
                        <p><strong>Stockage:</strong> <span id="storage">--</span></p>
                        <p><strong>Réseau:</strong> <span id="network">--</span></p>
                        <p><strong>Médias:</strong> <span id="media-count">--</span> fichiers</p>
                    </div>
                </div>
            </div>
        </div>

        <!-- Media Section -->
        <div id="media" class="content-section">
            <div class="header">
                <h1 class="page-title">Gestion des Médias</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="showUploadModal()">
                        📤 Upload
                    </button>
                </div>
            </div>

            <div class="upload-zone" id="upload-zone" ondrop="dropHandler(event);" ondragover="dragOverHandler(event);" ondragleave="dragLeaveHandler(event);">
                <div class="empty-state">
                    <div class="empty-state-icon">📁</div>
                    <div class="empty-state-title">Glisser-déposer des fichiers ici</div>
                    <div class="empty-state-text">ou cliquez pour parcourir</div>
                </div>
            </div>

            <div id="media-list" class="grid grid-3">
                <!-- Media files will be loaded here -->
            </div>
        </div>

        <!-- Playlists Section -->
        <div id="playlists" class="content-section">
            <div class="header">
                <h1 class="page-title">Playlists</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="createPlaylist()">
                        ➕ Nouvelle Playlist
                    </button>
                </div>
            </div>

            <div id="playlist-container">
                <!-- Playlists will be loaded here -->
            </div>
        </div>

        <!-- YouTube Section -->
        <div id="youtube" class="content-section">
            <div class="header">
                <h1 class="page-title">Téléchargement YouTube</h1>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📥</span>
                    Télécharger une vidéo
                </h3>
                <div class="form-group">
                    <label class="form-label">URL YouTube</label>
                    <input type="url" class="form-control" id="youtube-url" placeholder="https://www.youtube.com/watch?v=...">
                </div>
                <div class="form-group">
                    <label class="form-label">Qualité</label>
                    <select class="form-control" id="youtube-quality">
                        <option value="best">Meilleure qualité</option>
                        <option value="720p">720p</option>
                        <option value="480p">480p</option>
                        <option value="360p">360p</option>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Compression</label>
                    <select class="form-control" id="youtube-compression">
                        <option value="none">Aucune</option>
                        <option value="h264">H.264 Optimisé</option>
                        <option value="ultralight">Ultra léger</option>
                    </select>
                </div>
                <button class="btn btn-primary" onclick="downloadYoutube()">
                    📥 Télécharger
                </button>
                <div class="progress-bar" style="display: none;" id="youtube-progress">
                    <div class="progress-fill" id="youtube-progress-fill"></div>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📋</span>
                    Historique
                </h3>
                <div id="youtube-history">
                    <!-- History will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Player Section -->
        <div id="player" class="content-section">
            <div class="header">
                <h1 class="page-title">Contrôle du Lecteur</h1>
                <div class="header-actions">
                    <button class="btn btn-glass" onclick="takeQuickScreenshot('player')">
                        📸 Capture
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>🎮</span>
                    Contrôles VLC
                </h3>
                <div class="player-controls">
                    <div class="player-btn" onclick="vlcControl('play')">▶️</div>
                    <div class="player-btn" onclick="vlcControl('pause')">⏸️</div>
                    <div class="player-btn" onclick="vlcControl('stop')">⏹️</div>
                    <div class="player-btn" onclick="vlcControl('next')">⏭️</div>
                    <div class="player-btn" onclick="vlcControl('previous')">⏮️</div>
                </div>

                <div class="form-group">
                    <label class="form-label">Volume</label>
                    <input type="range" class="form-control" id="volume-control" min="0" max="100" value="50" onchange="setVolume(this.value)">
                </div>
            </div>


            <div class="card">
                <h3 class="card-title">
                    <span>📄</span>
                    Lecture de playlist
                </h3>
                <div class="form-group">
                    <label class="form-label">Sélectionner une playlist</label>
                    <select class="form-control" id="playlist-select">
                        <option value="">-- Choisir --</option>
                    </select>
                </div>
                <button class="btn btn-primary" onclick="playPlaylist()">
                    ▶️ Lancer
                </button>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📂</span>
                    Lecture de fichier
                </h3>
                <div class="form-group">
                    <label class="form-label">Sélectionner un fichier</label>
                    <select class="form-control" id="single-file-select">
                        <option value="">-- Choisir --</option>
                    </select>
                </div>
                <button class="btn btn-primary" onclick="playSingleFile()">
                    ▶️ Lancer
                </button>
            </div>
        </div>

        <!-- Schedule Section -->
        <div id="schedule" class="content-section">
            <div class="header">
                <h1 class="page-title">Programmation</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="addSchedule()">
                        ➕ Ajouter
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📅</span>
                    Calendrier
                </h3>
                <div id="schedule-list">
                    <!-- Schedule items will be loaded here -->
                </div>
            </div>
        </div>

        <!-- Screenshot Section -->
        <div id="screenshot" class="content-section">
            <div class="header">
                <h1 class="page-title">Capture d'écran</h1>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📸</span>
                    Capture en temps réel
                </h3>
                <div class="screenshot-preview" id="screenshot-preview">
                    <img id="screenshot-img" src="" alt="Capture d'écran" style="display: none;">
                    <div class="empty-state" id="screenshot-empty">
                        <div class="empty-state-icon">📸</div>
                        <div class="empty-state-title">Aucune capture</div>
                    </div>
                </div>
                <div class="player-controls">
                    <button class="btn btn-primary" onclick="takeScreenshot()">
                        📸 Prendre une capture
                    </button>
                    <button class="btn btn-glass" id="auto-capture-btn" onclick="toggleAutoCapture()">
                        🔄 Auto-capture (OFF)
                    </button>
                </div>
            </div>
        </div>

        <!-- Settings Section -->
        <div id="settings" class="content-section">
            <div class="header">
                <h1 class="page-title">Paramètres</h1>
            </div>

            <div class="grid grid-2">
                <div class="card">
                    <h3 class="card-title">
                        <span>🖥️</span>
                        Affichage
                    </h3>
                    <div class="form-group">
                        <label class="form-label">Résolution</label>
                        <select class="form-control" id="resolution">
                            <option value="1920x1080">1920x1080 (Full HD)</option>
                            <option value="1280x720">1280x720 (HD)</option>
                            <option value="1024x768">1024x768</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Rotation</label>
                        <select class="form-control" id="rotation">
                            <option value="0">0° (Normal)</option>
                            <option value="90">90° (Droite)</option>
                            <option value="180">180° (Inversé)</option>
                            <option value="270">270° (Gauche)</option>
                        </select>
                    </div>
                    <button class="btn btn-primary" onclick="saveDisplayConfig()">
                        💾 Appliquer
                    </button>
                </div>

                <div class="card">
                    <h3 class="card-title">
                        <span>🌐</span>
                        Réseau
                    </h3>
                    <div class="form-group">
                        <label class="form-label">WiFi SSID</label>
                        <input type="text" class="form-control" id="wifi-ssid" placeholder="Nom du réseau">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Mot de passe</label>
                        <input type="password" class="form-control" id="wifi-password" placeholder="Mot de passe">
                    </div>
                    <button class="btn btn-primary" onclick="saveNetworkConfig()">
                        💾 Appliquer
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>🔧</span>
                    Actions système
                </h3>
                <div style="display: flex; gap: 15px; flex-wrap: wrap;">
                    <button class="btn btn-danger" onclick="systemAction('reboot')">
                        🔄 Redémarrer
                    </button>
                    <button class="btn btn-danger" onclick="systemAction('shutdown')">
                        ⚡ Éteindre
                    </button>
                    <button class="btn btn-glass" onclick="systemAction('restart-vlc')">
                        🎵 Redémarrer VLC
                    </button>
                    <button class="btn btn-glass" onclick="systemAction('clear-cache')">
                        🗑️ Vider le cache
                    </button>
                </div>
            </div>
        </div>

        <!-- Logs Section -->
        <div id="logs" class="content-section">
            <div class="header">
                <h1 class="page-title">Logs Système</h1>
                <div class="header-actions">
                    <button class="btn btn-primary" onclick="refreshLogs()">
                        🔄 Actualiser
                    </button>
                </div>
            </div>

            <div class="card">
                <h3 class="card-title">
                    <span>📋</span>
                    Logs récents
                </h3>
                <div id="logs-content" style="background: rgba(0,0,0,0.3); padding: 20px; border-radius: 10px; font-family: monospace; font-size: 12px; max-height: 500px; overflow-y: auto;">
                    <!-- Logs will be loaded here -->
                </div>
            </div>
        </div>
    </div>

    <!-- Alert Container -->
    <div id="alert-container" style="position: fixed; top: 20px; right: 20px; z-index: 3000;"></div>

    <script>
        // Global variables
        let currentSection = 'dashboard';
        let autoScreenshotInterval = null;
        let systemStatsInterval = null;

        // Initialize
        document.addEventListener('DOMContentLoaded', () => {
            refreshStats();
            loadMediaFiles();
            loadPlaylists();

            // Auto refresh stats every 5 seconds
            systemStatsInterval = setInterval(refreshStats, 5000);
        });

        // Navigation
        function showSection(section) {
            // Update sections
            document.querySelectorAll('.content-section').forEach(el => {
                el.classList.remove('active');
            });
            document.getElementById(section).classList.add('active');

            // Update nav items
            document.querySelectorAll('.nav-item').forEach(el => {
                el.classList.remove('active');
                // Check if this nav item corresponds to the current section
                const onclick = el.getAttribute('onclick');
                if (onclick && onclick.includes(`'${section}'`)) {
                    el.classList.add('active');
                }
            });

            currentSection = section;
        }

        // Toggle sidebar (mobile)
        function toggleSidebar() {
            document.getElementById('sidebar').classList.toggle('active');
        }

        // Show alert
        function showAlert(message, type = 'info') {
            const alertDiv = document.createElement('div');
            alertDiv.className = `alert alert-${type}`;
            alertDiv.innerHTML = message;

            document.getElementById('alert-container').appendChild(alertDiv);

            setTimeout(() => {
                alertDiv.remove();
            }, 3000);
        }

        // System stats
        function refreshStats() {
            fetch('/api/system.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('cpu-usage').textContent = data.data.cpu + '%';
                        document.getElementById('ram-usage').textContent = data.data.ram + '%';
                        document.getElementById('temperature').textContent = data.data.temperature + '°C';
                        document.getElementById('uptime').textContent = data.data.uptime;
                        document.getElementById('storage').textContent = data.data.storage + '%';
                        document.getElementById('network').textContent = data.data.network;
                        document.getElementById('media-count').textContent = data.data.media_count;
                    }
                })
                .catch(error => console.error('Error loading stats:', error));
        }

        // VLC Control
        function vlcControl(action) {
            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: action })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(data.message || `Action ${action} exécutée!`, 'success');
                    updateVLCStatus();
                } else {
                    showAlert(data.message || `Erreur: ${action} a échoué`, 'error');
                }
            })
            .catch(error => showAlert('Erreur de communication', 'error'));
        }

        // Update VLC status
        function updateVLCStatus() {
            fetch('/api/player.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const status = data.running ? 'En lecture' : 'Arrêté';
                        document.getElementById('vlc-state').textContent = status;
                        document.getElementById('vlc-file').textContent = data.status || 'Aucun';
                        document.getElementById('vlc-position').textContent = '--:--';
                    }
                })
                .catch(error => console.error('Error:', error));
        }


        // Play single file
        function playSingleFile() {
            const file = document.getElementById('single-file-select').value;
            if (!file) {
                showAlert('Sélectionnez un fichier', 'error');
                return;
            }

            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'play-file',
                    file: file
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(data.message || 'Lecture démarrée!', 'success');
                    updateVLCStatus();
                } else {
                    showAlert(data.message || 'Erreur de lecture', 'error');
                }
            })
            .catch(error => showAlert('Erreur de communication', 'error'));
        }

        // Play playlist
        function playPlaylist() {
            const playlist = document.getElementById('playlist-select').value;
            if (!playlist) {
                showAlert('Sélectionnez une playlist', 'error');
                return;
            }

            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'play-playlist',
                    playlist: playlist
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(data.message || 'Playlist lancée!', 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de communication', 'error'));
        }

        // Screenshot functions
        function takeScreenshot() {
            showAlert('Capture en cours...', 'info');

            fetch('/api/screenshot-simple.php?action=capture')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const img = document.getElementById('screenshot-img');
                        const empty = document.getElementById('screenshot-empty');

                        img.src = data.data.url + '?' + Date.now();
                        img.style.display = 'block';
                        empty.style.display = 'none';

                        showAlert('Capture réalisée!', 'success');
                    } else {
                        showAlert('Erreur: ' + data.message, 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showAlert('Erreur lors de la capture', 'error');
                });
        }

        function takeQuickScreenshot(source) {
            showAlert(`Capture depuis ${source}...`, 'info');

            fetch('/api/screenshot-simple.php?action=capture')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        // Create modal
                        const modal = document.createElement('div');
                        modal.className = 'modal active';
                        modal.innerHTML = `
                            <div class="modal-content">
                                <h3 style="margin-bottom: 20px;">📸 Capture d'écran</h3>
                                <img src="${data.data.url}?${Date.now()}" style="width: 100%; border-radius: 10px;">
                                <button class="btn btn-primary" style="margin-top: 20px;" onclick="this.closest('.modal').remove()">
                                    Fermer
                                </button>
                            </div>
                        `;
                        document.body.appendChild(modal);

                        showAlert('Capture réalisée!', 'success');
                    } else {
                        showAlert('Erreur: ' + data.message, 'error');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    showAlert('Erreur lors de la capture', 'error');
                });
        }

        function toggleAutoCapture() {
            const btn = document.getElementById('auto-capture-btn');

            if (autoScreenshotInterval) {
                clearInterval(autoScreenshotInterval);
                autoScreenshotInterval = null;
                btn.textContent = '🔄 Auto-capture (OFF)';
                showAlert('Auto-capture désactivée', 'info');
            } else {
                autoScreenshotInterval = setInterval(takeScreenshot, 30000);
                btn.textContent = '🔄 Auto-capture (ON)';
                showAlert('Auto-capture activée (30s)', 'success');
            }
        }

        // Media management
        function loadMediaFiles() {
            fetch('/api/media.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const container = document.getElementById('media-list');
                        const fileSelect = document.getElementById('single-file-select');

                        container.innerHTML = '';
                        fileSelect.innerHTML = '<option value="">-- Choisir --</option>';

                        (data.data || []).forEach(file => {
                            // Add to grid
                            const card = document.createElement('div');
                            card.className = 'card';
                            card.innerHTML = `
                                <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                    <input type="checkbox" id="media-${file.name}" value="${file.name}" style="margin-right: 10px;">
                                    <h4 style="margin: 0; flex: 1;">${file.name}</h4>
                                </div>
                                <p>Taille: ${(file.size / 1024 / 1024).toFixed(2)} MB</p>
                                <p>Type: ${file.type}</p>
                                <button class="btn btn-danger" onclick="deleteFile('${file.name}')">
                                    🗑️ Supprimer
                                </button>
                            `;
                            container.appendChild(card);

                            // Add to select
                            const option = document.createElement('option');
                            option.value = file.name;
                            option.textContent = file.name;
                            fileSelect.appendChild(option);
                        });
                    }
                })
                .catch(error => console.error('Error loading media:', error));
        }

        function deleteFile(filename) {
            if (!confirm(`Supprimer ${filename}?`)) return;

            fetch('/api/media.php', {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ filename: filename, action: 'delete' })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Fichier supprimé!', 'success');
                    loadMediaFiles();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de suppression', 'error'));
        }

        // Playlist management
        function loadPlaylists() {
            fetch('/api/playlist.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const container = document.getElementById('playlist-container');
                        const select = document.getElementById('playlist-select');

                        container.innerHTML = '';
                        select.innerHTML = '<option value="">-- Choisir --</option>';

                        data.data.forEach(playlist => {
                            // Add to container
                            const card = document.createElement('div');
                            card.className = 'card';
                            card.innerHTML = `
                                <h3 class="card-title">${playlist.name}</h3>
                                <p>${playlist.items.length} fichiers</p>
                                <button class="btn btn-primary" onclick="editPlaylist('${playlist.name}')">
                                    ✏️ Modifier
                                </button>
                                <button class="btn btn-danger" onclick="deletePlaylist('${playlist.name}')">
                                    🗑️ Supprimer
                                </button>
                            `;
                            container.appendChild(card);

                            // Add to select
                            const option = document.createElement('option');
                            option.value = playlist.name;
                            option.textContent = playlist.name;
                            select.appendChild(option);
                        });
                    }
                })
                .catch(error => console.error('Error loading playlists:', error));
        }

        // Create new playlist
        function createPlaylist() {
            const name = prompt('Nom de la nouvelle playlist:');
            if (!name) return;

            // Get selected files from media section
            const selectedFiles = Array.from(document.querySelectorAll('#media input[type="checkbox"]:checked'))
                .map(cb => cb.value);

            fetch('/api/playlist.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'create',
                    name: name,
                    items: selectedFiles
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist créée!', 'success');
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de création', 'error'));
        }

        // Edit playlist
        function editPlaylist(name) {
            // Load playlist details
            fetch(`/api/playlist.php?action=info&name=${encodeURIComponent(name)}`)
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.data) {
                        const playlist = data.data;

                        // Create edit modal
                        const modalHTML = `
                            <div id="editPlaylistModal" style="display: block; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 9999;">
                                <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #2a2d3a; padding: 30px; border-radius: 10px; width: 600px; max-width: 90%; max-height: 80vh; overflow-y: auto;">
                                    <h2 style="margin: 0 0 20px; color: #4a9eff;">✏️ Modifier Playlist: ${name}</h2>

                                    <div style="margin-bottom: 20px;">
                                        <label style="display: block; margin-bottom: 5px;">Nom de la playlist:</label>
                                        <input type="text" id="edit-playlist-name" value="${name}" style="width: 100%; padding: 8px; background: #1a1a2e; border: 1px solid #4a9eff; border-radius: 5px; color: white;">
                                    </div>

                                    <div style="margin-bottom: 20px;">
                                        <label style="display: block; margin-bottom: 5px;">Fichiers dans la playlist:</label>
                                        <div id="edit-playlist-items" style="max-height: 200px; overflow-y: auto; border: 1px solid #4a9eff; padding: 10px; border-radius: 5px;">
                                            ${playlist.items.map(item => `
                                                <div style="margin-bottom: 5px;">
                                                    <input type="checkbox" id="item-${item}" value="${item}" checked>
                                                    <label for="item-${item}" style="margin-left: 5px;">${item}</label>
                                                </div>
                                            `).join('')}
                                        </div>
                                    </div>

                                    <div style="margin-bottom: 20px;">
                                        <label style="display: block; margin-bottom: 5px;">Ajouter des fichiers:</label>
                                        <select id="add-files-select" multiple style="width: 100%; height: 100px; background: #1a1a2e; border: 1px solid #4a9eff; color: white;">
                                            <!-- Will be populated with available files -->
                                        </select>
                                    </div>

                                    <div style="text-align: right;">
                                        <button class="btn btn-primary" onclick="savePlaylistChanges('${name}')">💾 Sauvegarder</button>
                                        <button class="btn btn-secondary" onclick="closeEditPlaylistModal()">Annuler</button>
                                    </div>
                                </div>
                            </div>
                        `;

                        // Remove existing modal if any
                        const existingModal = document.getElementById('editPlaylistModal');
                        if (existingModal) existingModal.remove();

                        // Add modal to page
                        document.body.insertAdjacentHTML('beforeend', modalHTML);

                        // Populate available files
                        fetch('/api/media.php?action=list')
                            .then(response => response.json())
                            .then(mediaData => {
                                if (mediaData.success && mediaData.data) {
                                    const select = document.getElementById('add-files-select');
                                    mediaData.data.forEach(file => {
                                        if (!playlist.items.includes(file.name)) {
                                            const option = document.createElement('option');
                                            option.value = file.name;
                                            option.textContent = file.name;
                                            select.appendChild(option);
                                        }
                                    });
                                }
                            });
                    } else {
                        showAlert('Erreur lors du chargement de la playlist', 'error');
                    }
                })
                .catch(error => showAlert('Erreur de chargement', 'error'));
        }

        function closeEditPlaylistModal() {
            const modal = document.getElementById('editPlaylistModal');
            if (modal) modal.remove();
        }

        function savePlaylistChanges(originalName) {
            const newName = document.getElementById('edit-playlist-name').value;

            // Get selected existing items
            const selectedItems = Array.from(document.querySelectorAll('#edit-playlist-items input:checked'))
                .map(cb => cb.value);

            // Get newly selected files
            const newFiles = Array.from(document.getElementById('add-files-select').selectedOptions)
                .map(option => option.value);

            const allItems = [...selectedItems, ...newFiles];

            fetch('/api/playlist.php', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'update',
                    oldName: originalName,
                    name: newName,
                    items: allItems
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist modifiée!', 'success');
                    closeEditPlaylistModal();
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de sauvegarde', 'error'));
        }

        // Delete playlist
        function deletePlaylist(name) {
            if (!confirm(`Supprimer la playlist "${name}"?`)) return;

            fetch('/api/playlist.php', {
                method: 'DELETE',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'delete',
                    name: name
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Playlist supprimée!', 'success');
                    loadPlaylists();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de suppression', 'error'));
        }

        // YouTube download avec monitoring
        let youtubeMonitorInterval = null;
        let downloadStartTime = null;
        let currentDownloadUrl = '';
        let currentDownloadQuality = '';

        function downloadYoutube() {
            const url = document.getElementById('youtube-url').value;
            const quality = document.getElementById('youtube-quality').value;

            // Sauvegarder pour l'historique
            currentDownloadUrl = url;
            currentDownloadQuality = quality;

            if (!url) {
                showAlert('Entrez une URL YouTube', 'error');
                return;
            }

            // Afficher le feedback détaillé
            showAlert('🚀 Lancement du téléchargement...', 'info');
            document.getElementById('youtube-progress').style.display = 'block';

            // Créer zone de feedback si elle n'existe pas
            let feedbackDiv = document.getElementById('youtube-feedback');
            if (!feedbackDiv) {
                feedbackDiv = document.createElement('div');
                feedbackDiv.id = 'youtube-feedback';
                feedbackDiv.style.cssText = 'margin-top: 20px; padding: 15px; background: rgba(0,0,0,0.3); border-radius: 8px; font-family: monospace; font-size: 12px; max-height: 200px; overflow-y: auto;';
                document.getElementById('youtube').appendChild(feedbackDiv);
            }
            feedbackDiv.innerHTML = '<div style="color: #4a9eff;">📥 Connexion à YouTube...</div>';

            downloadStartTime = Date.now();

            // Utiliser l'API simplifiée
            fetch('/api/youtube-simple.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    url: url,
                    quality: quality
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    feedbackDiv.innerHTML += '<div style="color: #4f4;">✅ Téléchargement lancé</div>';
                    feedbackDiv.innerHTML += '<div style="color: #999;">⏳ Récupération des informations vidéo...</div>';

                    // Démarrer le monitoring
                    startYoutubeMonitoring();
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                    document.getElementById('youtube-progress').style.display = 'none';
                }
            })
            .catch(error => {
                showAlert('Erreur de connexion', 'error');
                document.getElementById('youtube-progress').style.display = 'none';
            });
        }

        function startYoutubeMonitoring() {
            let checkCount = 0;
            const maxChecks = 120; // 10 minutes max

            youtubeMonitorInterval = setInterval(() => {
                checkCount++;

                fetch('/api/youtube-simple.php?action=status')
                    .then(response => response.json())
                    .then(data => {
                        const feedbackDiv = document.getElementById('youtube-feedback');
                        const progressBar = document.getElementById('youtube-progress-fill');

                        if (data.downloading) {
                            // Afficher les logs
                            if (data.log) {
                                const lines = data.log.split('\n').filter(l => l.trim());
                                const lastLine = lines[lines.length - 1] || '';

                                // Extraire le pourcentage si présent
                                const percentMatch = lastLine.match(/(\d+\.?\d*)%/);
                                if (percentMatch) {
                                    const percent = parseFloat(percentMatch[1]);
                                    if (progressBar) {
                                        progressBar.style.width = percent + '%';
                                    }
                                    feedbackDiv.innerHTML = '<div style="color: #4a9eff;">⏬ Téléchargement: ' + percent.toFixed(1) + '%</div>';
                                }

                                // Afficher info sur la vidéo
                                if (lastLine.includes('Destination:')) {
                                    const filename = lastLine.split('/').pop();
                                    feedbackDiv.innerHTML += '<div style="color: #fff;">📁 ' + filename + '</div>';
                                }
                            }
                        } else {
                            // Téléchargement terminé
                            clearInterval(youtubeMonitorInterval);
                            const elapsed = Math.round((Date.now() - downloadStartTime) / 1000);

                            feedbackDiv.innerHTML += '<div style="color: #4f4;">✅ Téléchargement terminé (' + elapsed + 's)</div>';
                            showAlert('✅ Vidéo téléchargée avec succès!', 'success');

                            document.getElementById('youtube-progress').style.display = 'none';

                            // Ajouter à l'historique
                            const historyDiv = document.getElementById('youtube-history');
                            if (historyDiv) {
                                const now = new Date().toLocaleString('fr-FR');
                                const historyItem = `
                                    <div style="padding: 10px; margin-bottom: 10px; background: rgba(74,158,255,0.1); border-radius: 5px; border-left: 3px solid #4a9eff;">
                                        <div style="color: #4a9eff; font-size: 12px;">${now}</div>
                                        <div style="color: #fff; margin: 5px 0;">✅ ${currentDownloadUrl}</div>
                                        <div style="color: #999; font-size: 11px;">Qualité: ${currentDownloadQuality} - Durée: ${elapsed}s</div>
                                    </div>
                                `;
                                historyDiv.innerHTML = historyItem + historyDiv.innerHTML;

                                // Limiter l'historique à 10 entrées
                                const items = historyDiv.children;
                                while (items.length > 10) {
                                    historyDiv.removeChild(items[items.length - 1]);
                                }
                            }

                            // Auto-refresh MEDIA
                            setTimeout(() => {
                                loadMediaFiles();
                                feedbackDiv.innerHTML += '<div style="color: #999;">📂 Section MEDIA mise à jour</div>';
                            }, 2000);

                            // Effacer le formulaire
                            document.getElementById('youtube-url').value = '';
                        }

                        // Timeout après 10 minutes
                        if (checkCount >= maxChecks) {
                            clearInterval(youtubeMonitorInterval);
                            feedbackDiv.innerHTML += '<div style="color: #f44;">⚠️ Timeout - Vérifiez les logs</div>';
                            document.getElementById('youtube-progress').style.display = 'none';
                        }
                    })
                    .catch(error => {
                        console.error('Monitoring error:', error);
                    });
            }, 5000); // Check toutes les 5 secondes
        }

        // System actions
        function systemAction(action) {
            if (action === 'reboot' || action === 'shutdown') {
                if (!confirm(`Êtes-vous sûr de vouloir ${action}?`)) return;
            }

            fetch('/api/system.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: action })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(`Action ${action} exécutée!`, 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur système', 'error'));
        }

        // Settings
        function saveDisplayConfig() {
            const resolution = document.getElementById('resolution').value;
            const rotation = document.getElementById('rotation').value;

            fetch('/api/config.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    type: 'display',
                    resolution: resolution,
                    rotation: rotation
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Configuration sauvegardée!', 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de sauvegarde', 'error'));
        }

        function saveNetworkConfig() {
            const ssid = document.getElementById('wifi-ssid').value;
            const password = document.getElementById('wifi-password').value;

            if (!ssid) {
                showAlert('Entrez un SSID', 'error');
                return;
            }

            fetch('/api/config.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    type: 'network',
                    ssid: ssid,
                    password: password
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('Configuration WiFi sauvegardée!', 'success');
                } else {
                    showAlert('Erreur: ' + data.message, 'error');
                }
            })
            .catch(error => showAlert('Erreur de sauvegarde', 'error'));
        }

        // Logs
        function refreshLogs() {
            fetch('/api/logs.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        document.getElementById('logs-content').innerHTML = data.data.logs.replace(/\n/g, '<br>');
                    }
                })
                .catch(error => console.error('Error loading logs:', error));
        }

        // Drag & Drop
        function dragOverHandler(ev) {
            ev.preventDefault();
            document.getElementById('upload-zone').classList.add('dragging');
        }

        function dragLeaveHandler(ev) {
            document.getElementById('upload-zone').classList.remove('dragging');
        }

        function dropHandler(ev) {
            ev.preventDefault();
            document.getElementById('upload-zone').classList.remove('dragging');

            const files = ev.dataTransfer.files;
            if (files.length > 0) {
                uploadFiles(files);
            }
        }

        function uploadFiles(files) {
            const formData = new FormData();
            let totalSize = 0;

            for (let i = 0; i < files.length; i++) {
                formData.append('files[]', files[i]);
                totalSize += files[i].size;
            }

            showAlert(`📤 Upload de ${files.length} fichier(s) - ${(totalSize/1024/1024).toFixed(1)}MB`, 'info');

            // Afficher une barre de progression
            const progressDiv = document.createElement('div');
            progressDiv.style.cssText = 'position: fixed; bottom: 20px; right: 20px; background: #2a2d3a; padding: 15px; border-radius: 8px; z-index: 1000; box-shadow: 0 4px 6px rgba(0,0,0,0.3);';
            progressDiv.innerHTML = `
                <div style="color: #4a9eff; margin-bottom: 10px;">Upload en cours...</div>
                <div style="width: 200px; height: 10px; background: rgba(255,255,255,0.1); border-radius: 5px;">
                    <div id="upload-progress-bar" style="width: 0%; height: 100%; background: #4a9eff; border-radius: 5px; transition: width 0.3s;"></div>
                </div>
            `;
            document.body.appendChild(progressDiv);

            const xhr = new XMLHttpRequest();

            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const percent = (e.loaded / e.total) * 100;
                    const bar = document.getElementById('upload-progress-bar');
                    if (bar) bar.style.width = percent + '%';
                }
            });

            xhr.onload = function() {
                if (xhr.status === 200) {
                    try {
                        const data = JSON.parse(xhr.responseText);
                        if (data.success) {
                            showAlert('✅ Upload terminé avec succès!', 'success');

                            // Auto-refresh MEDIA après un délai
                            setTimeout(() => {
                                loadMediaFiles();
                                showAlert('📂 Section MEDIA mise à jour', 'info');
                            }, 1000);
                        } else {
                            showAlert('Erreur: ' + data.message, 'error');
                        }
                    } catch (e) {
                        showAlert('Erreur de réponse serveur', 'error');
                    }
                }
                // Retirer la barre de progression
                setTimeout(() => {
                    if (progressDiv.parentNode) {
                        progressDiv.remove();
                    }
                }, 2000);
            };

            xhr.onerror = function() {
                showAlert('Erreur d\'upload', 'error');
                if (progressDiv.parentNode) {
                    progressDiv.remove();
                }
            };

            xhr.open('POST', '/api/upload.php');
            xhr.send(formData);
        }

        // Volume control
        function setVolume(value) {
            fetch('/api/player.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    action: 'volume',
                    value: value
                })
            })
            .catch(error => console.error('Volume error:', error));
        }

        // Upload Modal Functions
        function showUploadModal() {
            const modalHTML = `
                <div id="uploadModal" style="display: block; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 9999;">
                    <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: #2a2d3a; padding: 30px; border-radius: 10px; width: 500px; max-width: 90%;">
                        <h2 style="margin: 0 0 20px; color: #4a9eff;">📤 Upload de Fichiers</h2>
                        <div style="border: 2px dashed #4a9eff; padding: 40px; text-align: center; margin-bottom: 20px;">
                            <input type="file" id="uploadFiles" multiple accept="video/*,image/*" style="display: none;" onchange="handleFileSelect(this.files)">
                            <button class="btn btn-primary" onclick="document.getElementById('uploadFiles').click()">
                                Sélectionner des fichiers
                            </button>
                            <p style="margin: 10px 0; color: #999;">ou glissez-déposez ici</p>
                        </div>
                        <div style="text-align: right;">
                            <button class="btn btn-secondary" onclick="closeUploadModal()">Annuler</button>
                        </div>
                    </div>
                </div>
            `;

            // Remove existing modal if any
            const existingModal = document.getElementById('uploadModal');
            if (existingModal) {
                existingModal.remove();
            }

            // Add new modal
            document.body.insertAdjacentHTML('beforeend', modalHTML);

            // Add drag and drop
            const modal = document.getElementById('uploadModal');
            const dropZone = modal.querySelector('div[style*="border: 2px dashed"]');

            dropZone.addEventListener('dragover', (e) => {
                e.preventDefault();
                dropZone.style.borderColor = '#fff';
            });

            dropZone.addEventListener('dragleave', (e) => {
                e.preventDefault();
                dropZone.style.borderColor = '#4a9eff';
            });

            dropZone.addEventListener('drop', (e) => {
                e.preventDefault();
                dropZone.style.borderColor = '#4a9eff';
                handleFileSelect(e.dataTransfer.files);
            });
        }

        function closeUploadModal() {
            const modal = document.getElementById('uploadModal');
            if (modal) {
                modal.remove();
            }
        }

        function handleFileSelect(files) {
            if (files && files.length > 0) {
                closeUploadModal();
                uploadFile(files);
            }
        }
    </script>
</body>
</html>