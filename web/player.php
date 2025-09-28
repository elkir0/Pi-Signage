<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Enhanced Player Section -->
        <div id="player" class="content-section active">
            <div class="header">
                <h1 class="page-title">Contrôle du Lecteur</h1>
                <div class="header-actions">
                    <button class="btn btn-glass" onclick="refreshPlayerStatus()">
                        🔄 Actualiser
                    </button>
                    <button class="btn btn-glass" onclick="takeQuickScreenshot('player')">
                        📸 Capture
                    </button>
                </div>
            </div>

            <!-- Now Playing Card -->
            <div class="card now-playing-card">
                <div class="now-playing-header">
                    <div class="now-playing-info">
                        <h3 class="now-playing-title" id="now-playing-title">Aucun média en lecture</h3>
                        <p class="now-playing-meta" id="now-playing-meta">
                            <span class="player-state" id="player-state">Arrêté</span>
                            <span class="player-type">VLC</span>
                        </p>
                    </div>
                    <div class="now-playing-status">
                        <div class="status-indicator" id="status-indicator">
                            <span class="status-dot"></span>
                            <span id="status-text">Hors ligne</span>
                        </div>
                    </div>
                </div>

                <!-- Progress Bar -->
                <div class="progress-section">
                    <span class="time-current" id="time-current">00:00</span>
                    <div class="progress-bar-container">
                        <div class="progress-bar-bg">
                            <div class="progress-bar-fill" id="progress-fill" style="width: 0%"></div>
                            <input type="range" class="progress-bar-input" id="seek-bar"
                                   min="0" max="100" value="0"
                                   onchange="seekTo(this.value)"
                                   oninput="updateSeekPreview(this.value)">
                        </div>
                    </div>
                    <span class="time-total" id="time-total">00:00</span>
                </div>

                <!-- Transport Controls -->
                <div class="transport-controls">
                    <button class="control-btn secondary" id="shuffle-btn" onclick="toggleShuffle()" title="Aléatoire">
                        🔀
                    </button>
                    <button class="control-btn" id="previous-btn" onclick="playerControl('previous')" title="Précédent">
                        ⏮️
                    </button>
                    <button class="control-btn primary" id="play-pause-btn" onclick="togglePlayPause()" title="Lecture/Pause">
                        ▶️
                    </button>
                    <button class="control-btn" id="stop-btn" onclick="playerControl('stop')" title="Arrêt">
                        ⏹️
                    </button>
                    <button class="control-btn" id="next-btn" onclick="playerControl('next')" title="Suivant">
                        ⏭️
                    </button>
                    <button class="control-btn secondary" id="loop-btn" onclick="toggleLoop()" title="Répéter">
                        🔁
                    </button>
                </div>

                <!-- Volume Control -->
                <div class="volume-section">
                    <button class="volume-btn" id="mute-btn" onclick="toggleMute()" title="Muet">
                        🔊
                    </button>
                    <div class="volume-slider-container">
                        <input type="range" class="volume-slider" id="volume-slider"
                               min="0" max="100" value="50"
                               oninput="setVolume(this.value)">
                        <div class="volume-fill" id="volume-fill" style="width: 50%"></div>
                    </div>
                    <span class="volume-value" id="volume-value">50%</span>
                </div>
            </div>

            <!-- Playlist Control Card -->
            <div class="card">
                <h3 class="card-title">
                    <span>🎵</span>
                    Gestion des Playlists
                </h3>

                <div class="playlist-control-grid">
                    <!-- Playlist Selector -->
                    <div class="playlist-selector-section">
                        <div class="form-group">
                            <label class="form-label">Playlist active</label>
                            <select class="form-control" id="playlist-select" onchange="previewPlaylist()">
                                <option value="">-- Sélectionner une playlist --</option>
                            </select>
                        </div>

                        <div class="playlist-actions">
                            <button class="btn btn-primary" onclick="loadPlaylist()">
                                ▶️ Charger
                            </button>
                            <button class="btn btn-glass" onclick="showPlaylistQueue()">
                                📋 File d'attente
                            </button>
                        </div>
                    </div>

                    <!-- Current Queue -->
                    <div class="queue-section" id="queue-section" style="display: none;">
                        <h4>File d'attente actuelle</h4>
                        <div class="queue-list" id="queue-list">
                            <!-- Queue items will be loaded here -->
                        </div>
                    </div>
                </div>
            </div>

            <!-- Quick Media Control -->
            <div class="card">
                <h3 class="card-title">
                    <span>📂</span>
                    Lecture rapide
                </h3>

                <div class="quick-play-grid">
                    <div class="form-group">
                        <label class="form-label">Fichier média</label>
                        <select class="form-control" id="media-select">
                            <option value="">-- Sélectionner un fichier --</option>
                        </select>
                    </div>

                    <div class="quick-play-actions">
                        <button class="btn btn-primary" onclick="playMediaFile()">
                            ▶️ Lire maintenant
                        </button>
                        <button class="btn btn-secondary" onclick="addMediaToQueue()">
                            ➕ Ajouter à la file
                        </button>
                    </div>
                </div>
            </div>

            <!-- System Stats -->
            <div class="card">
                <h3 class="card-title">
                    <span>📊</span>
                    Statistiques système
                </h3>
                <div class="system-stats-grid">
                    <div class="stat-item">
                        <label>CPU</label>
                        <span id="player-cpu">--</span>
                    </div>
                    <div class="stat-item">
                        <label>Mémoire</label>
                        <span id="player-memory">--</span>
                    </div>
                    <div class="stat-item">
                        <label>Température</label>
                        <span id="player-temp">--</span>
                    </div>
                    <div class="stat-item">
                        <label>Uptime</label>
                        <span id="player-uptime">--</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

<?php include 'includes/footer.php'; ?>