<?php
require_once 'includes/auth.php';
require_once 'config.php';

$pageTitle = "Contrôle du Lecteur";
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($pageTitle) ?> - PiSignage</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
    <style>
        .player-status {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 15px;
            padding: 2rem;
            margin-bottom: 2rem;
        }
        .control-btn {
            width: 80px;
            height: 80px;
            border-radius: 50%;
            font-size: 2rem;
            transition: all 0.3s ease;
        }
        .control-btn:hover {
            transform: scale(1.1);
        }
        .volume-slider {
            width: 100%;
            height: 8px;
        }
        .progress-bar-custom {
            height: 10px;
            background: rgba(255,255,255,0.2);
            border-radius: 5px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: white;
            transition: width 0.3s ease;
        }
        .status-badge {
            font-size: 1.2rem;
            padding: 0.5rem 1.5rem;
            border-radius: 20px;
        }
    </style>
</head>
<body class="bg-light">
    <?php include 'includes/navigation.php'; ?>

    <div class="container-fluid mt-4">
        <div class="row">
            <div class="col-12">
                <h1 class="mb-4"><i class="bi bi-play-circle-fill"></i> <?= htmlspecialchars($pageTitle) ?></h1>
            </div>
        </div>

        <!-- Player Status -->
        <div class="row">
            <div class="col-12">
                <div class="player-status">
                    <div class="row align-items-center">
                        <div class="col-md-8">
                            <div class="d-flex align-items-center mb-3">
                                <span class="status-badge bg-success me-3" id="playerState">
                                    <i class="bi bi-circle-fill"></i> Chargement...
                                </span>
                                <span class="badge bg-light text-dark">VLC Player</span>
                            </div>
                            <h3 class="mb-2" id="currentFile">Aucun fichier en lecture</h3>
                            <div class="progress-bar-custom mb-2">
                                <div class="progress-fill" id="progressBar" style="width: 0%"></div>
                            </div>
                            <div class="d-flex justify-content-between">
                                <span id="currentTime">00:00</span>
                                <span id="duration">00:00</span>
                            </div>
                        </div>
                        <div class="col-md-4 text-center">
                            <div class="display-4 mb-2" id="volumeDisplay">100%</div>
                            <small>Volume</small>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Playback Controls -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card shadow-sm">
                    <div class="card-body text-center py-4">
                        <h5 class="card-title mb-4">Contrôles de Lecture</h5>
                        <div class="d-flex justify-content-center gap-3 flex-wrap">
                            <button class="btn btn-primary control-btn" onclick="playerControl('previous')" title="Précédent">
                                <i class="bi bi-skip-start-fill"></i>
                            </button>
                            <button class="btn btn-success control-btn" id="playPauseBtn" onclick="togglePlayPause()" title="Lecture/Pause">
                                <i class="bi bi-play-fill" id="playPauseIcon"></i>
                            </button>
                            <button class="btn btn-danger control-btn" onclick="playerControl('stop')" title="Stop">
                                <i class="bi bi-stop-fill"></i>
                            </button>
                            <button class="btn btn-primary control-btn" onclick="playerControl('next')" title="Suivant">
                                <i class="bi bi-skip-end-fill"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Volume Control -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title mb-4">
                            <i class="bi bi-volume-up-fill"></i> Contrôle du Volume
                        </h5>
                        <div class="row align-items-center">
                            <div class="col-md-10">
                                <input type="range" class="form-range volume-slider" min="0" max="320" value="256" id="volumeSlider">
                                <div class="d-flex justify-content-between text-muted small">
                                    <span>Muet</span>
                                    <span>50%</span>
                                    <span>100%</span>
                                    <span>125%</span>
                                </div>
                            </div>
                            <div class="col-md-2 text-center">
                                <button class="btn btn-outline-secondary" onclick="toggleMute()" id="muteBtn">
                                    <i class="bi bi-volume-up-fill" id="muteIcon"></i>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Quick Actions -->
        <div class="row">
            <div class="col-md-6 mb-3">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title"><i class="bi bi-fullscreen"></i> Affichage</h5>
                        <button class="btn btn-outline-primary w-100" onclick="toggleFullscreen()">
                            <i class="bi bi-arrows-fullscreen"></i> Basculer Plein Écran
                        </button>
                    </div>
                </div>
            </div>
            <div class="col-md-6 mb-3">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title"><i class="bi bi-list-task"></i> Playlist</h5>
                        <button class="btn btn-outline-danger w-100" onclick="clearPlaylist()">
                            <i class="bi bi-trash"></i> Vider la Playlist
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Status Log -->
        <div class="row mt-4">
            <div class="col-12">
                <div class="card shadow-sm">
                    <div class="card-body">
                        <h5 class="card-title"><i class="bi bi-terminal"></i> Journal d'Événements</h5>
                        <div id="statusLog" style="max-height: 200px; overflow-y: auto; font-family: monospace; font-size: 0.9rem;">
                            <div class="text-muted">Chargement...</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentVolume = 256;
        let isMuted = false;
        let isPlaying = false;
        let previousVolume = 256;

        // Update status every 2 seconds
        setInterval(updateStatus, 2000);
        updateStatus(); // Initial load

        // Volume slider
        document.getElementById('volumeSlider').addEventListener('input', function() {
            const volume = parseInt(this.value);
            setVolume(volume);
        });

        async function updateStatus() {
            try {
                const response = await fetch('/api/player-control.php?action=status');
                const data = await response.json();
                
                if (data.success) {
                    const status = data;
                    
                    // Update state
                    const state = status.state || 'unknown';
                    isPlaying = (state === 'playing');
                    const stateText = state === 'playing' ? 'En Lecture' : 
                                     state === 'paused' ? 'En Pause' : 
                                     state === 'stopped' ? 'Arrêté' : 'Inconnu';
                    const stateClass = state === 'playing' ? 'bg-success' : 
                                      state === 'paused' ? 'bg-warning' : 'bg-secondary';
                    
                    document.getElementById('playerState').innerHTML = `<i class="bi bi-circle-fill"></i> ${stateText}`;
                    document.getElementById('playerState').className = `status-badge ${stateClass} me-3`;
                    
                    // Update play/pause icon
                    const icon = document.getElementById('playPauseIcon');
                    icon.className = isPlaying ? 'bi bi-pause-fill' : 'bi bi-play-fill';
                    
                    // Update current file
                    document.getElementById('currentFile').textContent = status.current_file || 'Aucun fichier en lecture';
                    
                    // Update time and progress
                    const time = status.time || 0;
                    const length = status.length || 0;
                    document.getElementById('currentTime').textContent = formatTime(time);
                    document.getElementById('duration').textContent = formatTime(length);
                    
                    const progress = length > 0 ? (time / length) * 100 : 0;
                    document.getElementById('progressBar').style.width = progress + '%';
                    
                    // Update volume (only if not currently adjusting)
                    if (!document.getElementById('volumeSlider').matches(':active')) {
                        currentVolume = status.volume || 256;
                        document.getElementById('volumeSlider').value = currentVolume;
                        const volumePercent = Math.round((currentVolume / 256) * 100);
                        document.getElementById('volumeDisplay').textContent = volumePercent + '%';
                    }
                    
                    logEvent(`Status: ${stateText} - ${status.current_file || 'N/A'}`);
                }
            } catch (error) {
                console.error('Error updating status:', error);
                logEvent('Erreur: Impossible de récupérer le statut', 'error');
            }
        }

        async function playerControl(action) {
            try {
                const response = await fetch(`/api/player-control.php?action=${action}`, {
                    method: 'POST'
                });
                const data = await response.json();
                
                if (data.success) {
                    logEvent(`Action: ${action} - Succès`);
                    setTimeout(updateStatus, 500);
                } else {
                    logEvent(`Action: ${action} - Échec`, 'error');
                }
            } catch (error) {
                console.error('Error:', error);
                logEvent(`Erreur: ${action}`, 'error');
            }
        }

        async function togglePlayPause() {
            const action = isPlaying ? 'pause' : 'play';
            await playerControl(action);
        }

        async function setVolume(volume) {
            currentVolume = volume;
            const volumePercent = Math.round((volume / 256) * 100);
            document.getElementById('volumeDisplay').textContent = volumePercent + '%';
            
            try {
                const response = await fetch('/api/player-control.php?action=volume', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({volume: volume})
                });
                const data = await response.json();
                
                if (data.success) {
                    logEvent(`Volume: ${volumePercent}%`);
                }
            } catch (error) {
                console.error('Error setting volume:', error);
            }
        }

        async function toggleMute() {
            if (isMuted) {
                // Unmute
                await setVolume(previousVolume);
                isMuted = false;
                document.getElementById('muteIcon').className = 'bi bi-volume-up-fill';
                document.getElementById('muteBtn').className = 'btn btn-outline-secondary';
            } else {
                // Mute
                previousVolume = currentVolume;
                await setVolume(0);
                isMuted = true;
                document.getElementById('muteIcon').className = 'bi bi-volume-mute-fill';
                document.getElementById('muteBtn').className = 'btn btn-danger';
            }
        }

        async function toggleFullscreen() {
            await playerControl('fullscreen');
        }

        async function clearPlaylist() {
            if (confirm('Êtes-vous sûr de vouloir vider la playlist ?')) {
                try {
                    const response = await fetch('/api/player-control.php?action=clear_playlist', {
                        method: 'POST'
                    });
                    const data = await response.json();
                    
                    if (data.success) {
                        logEvent('Playlist vidée');
                        setTimeout(updateStatus, 500);
                    }
                } catch (error) {
                    console.error('Error:', error);
                }
            }
        }

        function formatTime(seconds) {
            if (!seconds || seconds < 0) return '00:00';
            const mins = Math.floor(seconds / 60);
            const secs = Math.floor(seconds % 60);
            return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        }

        function logEvent(message, type = 'info') {
            const log = document.getElementById('statusLog');
            const timestamp = new Date().toLocaleTimeString('fr-FR');
            const color = type === 'error' ? 'text-danger' : 'text-success';
            
            const entry = document.createElement('div');
            entry.className = color;
            entry.textContent = `[${timestamp}] ${message}`;
            
            log.insertBefore(entry, log.firstChild);
            
            // Keep only last 20 entries
            while (log.children.length > 20) {
                log.removeChild(log.lastChild);
            }
        }
    </script>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
