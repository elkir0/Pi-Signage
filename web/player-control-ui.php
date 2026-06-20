<?php
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Player Control Section -->
        <div id="player-control" class="content-section active">
            <div class="header">
                <h1 class="page-title">Contrôle du Lecteur</h1>
                <div class="header-actions">
                    <span class="badge" id="player-mode-badge">VLC Player</span>
                </div>
            </div>

            <!-- Player Status Card -->
            <div class="card">
                <div class="card-header">
                    <h2>État du Lecteur</h2>
                    <span class="badge badge-success" id="player-state">Chargement...</span>
                </div>
                <div class="card-body">
                    <div class="player-status-info">
                        <div class="status-item">
                            <label>Fichier en lecture:</label>
                            <strong id="current-file">Aucun fichier</strong>
                        </div>
                        <div class="progress-bar" style="margin: 1rem 0;">
                            <div class="progress-fill" id="progress-bar" style="width: 0%;"></div>
                        </div>
                        <div class="status-row">
                            <span id="current-time">00:00</span>
                            <span id="duration">00:00</span>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Playback Controls -->
            <div class="card">
                <div class="card-header">
                    <h2>Contrôles de Lecture</h2>
                </div>
                <div class="card-body">
                    <div class="player-controls">
                        <button class="btn btn-secondary" onclick="playerControl('previous')" title="Précédent">
                            ⏮️ Précédent
                        </button>
                        <button class="btn btn-primary" id="play-pause-btn" onclick="togglePlayPause()" title="Lecture/Pause">
                            <span id="play-pause-icon">▶️</span> <span id="play-pause-text">Play</span>
                        </button>
                        <button class="btn btn-danger" onclick="playerControl('stop')" title="Stop">
                            ⏹️ Stop
                        </button>
                        <button class="btn btn-secondary" onclick="playerControl('next')" title="Suivant">
                            ⏭️ Suivant
                        </button>
                    </div>
                </div>
            </div>

            <!-- Volume Controls -->
            <div class="grid grid-2">
                <!-- VLC Volume -->
                <div class="card">
                    <div class="card-header">
                        <h2>🎵 Volume VLC</h2>
                        <span class="badge" id="vlc-volume-display">100%</span>
                    </div>
                    <div class="card-body">
                        <input type="range" class="form-range" min="0" max="320" value="256" id="vlc-volume-slider">
                        <div class="range-labels">
                            <span>0%</span>
                            <span>100%</span>
                            <span>125%</span>
                        </div>
                        <button class="btn btn-secondary btn-sm" onclick="toggleVLCMute()" id="vlc-mute-btn" style="margin-top: 1rem;">
                            <span id="vlc-mute-icon">🔇</span> <span id="vlc-mute-text">Mute</span>
                        </button>
                    </div>
                </div>

                <!-- System Volume (ALSA) -->
                <div class="card">
                    <div class="card-header">
                        <h2>🔊 Volume Système (ALSA)</h2>
                        <span class="badge" id="system-volume-display">--</span>
                    </div>
                    <div class="card-body">
                        <input type="range" class="form-range" min="0" max="100" value="100" id="system-volume-slider">
                        <div class="range-labels">
                            <span>0%</span>
                            <span>50%</span>
                            <span>100%</span>
                        </div>
                        <button class="btn btn-secondary btn-sm" onclick="toggleSystemMute()" id="system-mute-btn" style="margin-top: 1rem;">
                            <span id="system-mute-icon">🔇</span> <span id="system-mute-text">Mute</span>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="grid grid-2">
                <div class="card">
                    <div class="card-header">
                        <h2>Actions Rapides</h2>
                    </div>
                    <div class="card-body">
                        <button class="btn btn-outline-primary" onclick="toggleFullscreen()">
                            🖥️ Basculer Plein Écran
                        </button>
                        <button class="btn btn-outline-danger" onclick="clearPlaylist()" style="margin-top: 0.5rem;">
                            🗑️ Vider la Playlist
                        </button>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <h2>Journal</h2>
                    </div>
                    <div class="card-body">
                        <div id="status-log" style="max-height: 150px; overflow-y: auto; font-size: 0.85rem; font-family: monospace;">
                            <div style="color: #666;">Chargement...</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

<style>
.player-controls {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
}

.player-status-info {
    padding: 1rem;
}

.status-item {
    margin-bottom: 0.5rem;
}

.status-item label {
    color: #666;
    font-size: 0.9rem;
    display: block;
    margin-bottom: 0.25rem;
}

.status-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.9rem;
    color: #666;
}

.progress-bar {
    height: 8px;
    background: #e0e0e0;
    border-radius: 4px;
    overflow: hidden;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #4CAF50, #45a049);
    transition: width 0.3s ease;
}

.range-labels {
    display: flex;
    justify-content: space-between;
    font-size: 0.8rem;
    color: #666;
    margin-top: 0.25rem;
}

.form-range {
    width: 100%;
    height: 8px;
    border-radius: 4px;
    background: #e0e0e0;
    outline: none;
    margin: 0.5rem 0;
}

.form-range::-webkit-slider-thumb {
    appearance: none;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #4CAF50;
    cursor: pointer;
}

.form-range::-moz-range-thumb {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #4CAF50;
    cursor: pointer;
}
</style>

<script>
let vlcVolume = 256;
let vlcMuted = false;
let vlcPreviousVolume = 256;
let isPlaying = false;
let systemVolume = 100;
let systemMuted = false;

// Update status every 2 seconds
setInterval(updatePlayerStatus, 2000);
updatePlayerStatus();
updateSystemVolume();

// VLC Volume slider
document.getElementById('vlc-volume-slider').addEventListener('input', function() {
    const volume = parseInt(this.value);
    setVLCVolume(volume);
});

// System Volume slider
document.getElementById('system-volume-slider').addEventListener('input', function() {
    const volume = parseInt(this.value);
    setSystemVolume(volume);
});

async function updatePlayerStatus() {
    try {
        const response = await fetch('/api/player-control.php?action=status');
        const result = await response.json();

        if (result.success && result.data) {
            const data = result.data;
            const state = data.state || 'unknown';
            isPlaying = (state === 'playing');

            // Update state badge
            const stateBadge = document.getElementById('player-state');
            if (stateBadge) {
                const stateText = state === 'playing' ? 'En Lecture' :
                                 state === 'paused' ? 'En Pause' :
                                 state === 'stopped' ? 'Arrêté' : 'Inconnu';
                stateBadge.textContent = stateText;
                stateBadge.className = 'badge ' + (state === 'playing' ? 'badge-success' : state === 'paused' ? 'badge-warning' : 'badge-secondary');
            }

            // Update play/pause button
            const playPauseIcon = document.getElementById('play-pause-icon');
            const playPauseText = document.getElementById('play-pause-text');
            if (playPauseIcon) playPauseIcon.textContent = isPlaying ? '⏸️' : '▶️';
            if (playPauseText) playPauseText.textContent = isPlaying ? 'Pause' : 'Play';

            // Update current file
            const currentFileEl = document.getElementById('current-file');
            if (currentFileEl) currentFileEl.textContent = data.current_file || 'Aucun fichier';

            // Update time and progress
            const time = data.position || 0;
            const length = data.duration || 0;
            const currentTimeEl = document.getElementById('current-time');
            const durationEl = document.getElementById('duration');
            if (currentTimeEl) currentTimeEl.textContent = formatTime(time);
            if (durationEl) durationEl.textContent = formatTime(length);

            const progress = length > 0 ? (time / length) * 100 : 0;
            const progressBar = document.getElementById('progress-bar');
            if (progressBar) progressBar.style.width = progress + '%';

            // Update VLC volume if not currently adjusting
            const vlcVolumeSlider = document.getElementById('vlc-volume-slider');
            const vlcVolumeDisplay = document.getElementById('vlc-volume-display');
            if (vlcVolumeSlider && !vlcVolumeSlider.matches(':active')) {
                vlcVolume = data.volume || 256;
                vlcVolumeSlider.value = vlcVolume;
                const volumePercent = Math.round((vlcVolume / 256) * 100);
                if (vlcVolumeDisplay) vlcVolumeDisplay.textContent = volumePercent + '%';
            }
        }
    } catch (error) {
        console.error('Error updating status:', error);
    }
}

async function updateSystemVolume() {
    try {
        const response = await fetch('/api/system.php?action=get_volume');
        const data = await response.json();

        if (data.success && data.volume !== undefined) {
            systemVolume = data.volume;
            document.getElementById('system-volume-slider').value = systemVolume;
            document.getElementById('system-volume-display').textContent = systemVolume + '%';
        }
    } catch (error) {
        console.error('Error getting system volume:', error);
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
            setTimeout(updatePlayerStatus, 500);
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

async function setVLCVolume(volume) {
    vlcVolume = volume;
    const volumePercent = Math.round((volume / 256) * 100);
    document.getElementById('vlc-volume-display').textContent = volumePercent + '%';

    try {
        const response = await fetch('/api/player-control.php?action=volume', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({volume: volume})
        });
        const data = await response.json();

        if (data.success) {
            logEvent(`Volume VLC: ${volumePercent}%`);
        }
    } catch (error) {
        console.error('Error setting VLC volume:', error);
    }
}

async function setSystemVolume(volume) {
    systemVolume = volume;
    document.getElementById('system-volume-display').textContent = volume + '%';

    try {
        const response = await fetch('/api/system.php?action=set_volume', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({volume: volume})
        });
        const data = await response.json();

        if (data.success) {
            logEvent(`Volume Système: ${volume}%`);
        }
    } catch (error) {
        console.error('Error setting system volume:', error);
    }
}

async function toggleVLCMute() {
    if (vlcMuted) {
        await setVLCVolume(vlcPreviousVolume);
        vlcMuted = false;
        document.getElementById('vlc-mute-icon').textContent = '🔊';
        document.getElementById('vlc-mute-text').textContent = 'Mute';
    } else {
        vlcPreviousVolume = vlcVolume;
        await setVLCVolume(0);
        vlcMuted = true;
        document.getElementById('vlc-mute-icon').textContent = '🔇';
        document.getElementById('vlc-mute-text').textContent = 'Unmute';
    }
}

async function toggleSystemMute() {
    try {
        const response = await fetch('/api/system.php?action=toggle_mute', {
            method: 'POST'
        });
        const data = await response.json();

        if (data.success) {
            systemMuted = data.muted;
            document.getElementById('system-mute-icon').textContent = systemMuted ? '🔇' : '🔊';
            document.getElementById('system-mute-text').textContent = systemMuted ? 'Unmute' : 'Mute';
            logEvent(systemMuted ? 'Système muté' : 'Système démuté');
        }
    } catch (error) {
        console.error('Error toggling system mute:', error);
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
                setTimeout(updatePlayerStatus, 500);
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
    const log = document.getElementById('status-log');
    const timestamp = new Date().toLocaleTimeString('fr-FR');
    const color = type === 'error' ? '#dc3545' : '#28a745';

    const entry = document.createElement('div');
    entry.style.color = color;
    entry.textContent = `[${timestamp}] ${message}`;

    log.insertBefore(entry, log.firstChild);

    // Keep only last 10 entries
    while (log.children.length > 10) {
        log.removeChild(log.lastChild);
    }
}
</script>

<?php include 'includes/footer.php'; ?>
