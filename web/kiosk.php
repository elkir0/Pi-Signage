<?php
/**
 * PiSignage Kiosk Control
 * Interface de gestion du mode Kiosk Chromium + Playlist Player
 */
require_once 'includes/auth.php';
requireAuth();
include 'includes/header.php';
?>

<?php include 'includes/navigation.php'; ?>

<div class="main-content">
    <div id="kiosk-control" class="content-section active">
        <div class="header">
            <h1 class="page-title">🖥️ Kiosk Control</h1>
            <div class="header-actions">
                <button class="btn btn-glass" onclick="refreshStatus()">
                    🔄 Actualiser
                </button>
            </div>
        </div>

        <!-- Section 1: Mode Kiosk -->
        <div class="card">
            <h3 class="card-title">
                <span>⚙️</span>
                Mode Kiosk
            </h3>
            <div class="kiosk-mode-controls">
                <div class="mode-selector">
                    <label class="switch-container">
                        <span class="switch-label">Activer le mode Kiosk</span>
                        <input type="checkbox" id="enable-kiosk" class="switch-input">
                        <span class="switch-slider"></span>
                    </label>
                    <p class="help-text">Active/désactive l'affichage Chromium en kiosk au démarrage</p>
                </div>

                <div class="mode-selector" style="margin-top: 20px;">
                    <label class="switch-container">
                        <span class="switch-label">Utiliser Chromium Player (HTML5)</span>
                        <input type="checkbox" id="use-chromium-player" class="switch-input">
                        <span class="switch-slider"></span>
                    </label>
                    <p class="help-text">
                        ON: Chromium joue la playlist en HTML5 video<br>
                        OFF: Fallback VLC (lecture classique)
                    </p>
                </div>
            </div>
        </div>

        <!-- Section 2: Playlist Management -->
        <div class="card">
            <h3 class="card-title">
                <span>📋</span>
                Playlist Chromium Player
            </h3>
            
            <div class="playlist-header">
                <button class="btn btn-primary" onclick="addPlaylistItem()">
                    ➕ Ajouter média
                </button>
                <button class="btn btn-glass" onclick="uploadMedia()">
                    📤 Upload fichier
                </button>
                <button class="btn btn-success" onclick="savePlaylist()">
                    💾 Sauvegarder playlist
                </button>
                <button class="btn btn-glass" onclick="validatePlaylist()">
                    ✅ Valider
                </button>
            </div>

            <!-- Playlist items list -->
            <div id="playlist-items" class="playlist-items">
                <p class="loading-message">Chargement de la playlist...</p>
            </div>

            <!-- Playlist global settings -->
            <div class="playlist-settings">
                <h4>Paramètres globaux</h4>
                <label class="checkbox-container">
                    <input type="checkbox" id="playlist-autoplay" checked>
                    <span>Lecture automatique au démarrage</span>
                </label>
                <label class="checkbox-container">
                    <input type="checkbox" id="playlist-autoloop" checked>
                    <span>Boucler la playlist automatiquement</span>
                </label>
            </div>
        </div>

        <!-- Section 3: URL Kiosk -->
        <div class="card">
            <h3 class="card-title">
                <span>🔗</span>
                URL Kiosk (mode dashboard)
            </h3>
            <div class="form-group">
                <label for="kiosk-url">URL à afficher dans Chromium</label>
                <input 
                    type="url" 
                    id="kiosk-url" 
                    class="form-control" 
                    placeholder="http://127.0.0.1/player"
                >
                <p class="help-text">
                    Pour le player HTML5: http://127.0.0.1/player<br>
                    Pour un dashboard: https://grafana.local, etc.
                </p>
                <button class="btn btn-primary" onclick="updateKioskUrl()">
                    💾 Sauvegarder URL
                </button>
            </div>
        </div>

        <!-- Section 4: Chromium Flags -->
        <div class="card">
            <h3 class="card-title">
                <span>🚩</span>
                Flags Chromium
            </h3>
            <div class="form-group">
                <label for="chromium-flags">Arguments Chromium (un par ligne)</label>
                <textarea 
                    id="chromium-flags" 
                    class="form-control monospace" 
                    rows="10"
                    placeholder="--ozone-platform=wayland&#10;--enable-features=VaapiVideoDecoder,UseOzonePlatform&#10;--autoplay-policy=no-user-gesture-required"
                ></textarea>
                <p class="help-text">
                    Flags recommandés pour Wayland + hardware accel déjà inclus.<br>
                    Éditer avec précaution.
                </p>
                <button class="btn btn-primary" onclick="updateChromiumFlags()">
                    💾 Sauvegarder flags
                </button>
                <button class="btn btn-glass" onclick="resetChromiumFlags()">
                    🔄 Réinitialiser aux valeurs par défaut
                </button>
            </div>
        </div>

        <!-- Section 5: Status (auto-refresh) -->
        <div class="card">
            <h3 class="card-title">
                <span>📊</span>
                Statut Kiosk
                <span class="auto-refresh-indicator" id="status-indicator">●</span>
            </h3>
            <div id="kiosk-status" class="kiosk-status">
                <p class="loading-message">Chargement du statut...</p>
            </div>
        </div>

        <!-- Section 6: Actions -->
        <div class="card">
            <h3 class="card-title">
                <span>⚡</span>
                Actions
            </h3>
            <div class="action-buttons">
                <button class="btn btn-danger" onclick="restartKiosk()">
                    🔄 Redémarrer Chromium
                </button>
                <button class="btn btn-glass" onclick="refreshPlaylist()">
                    🔃 Recharger playlist
                </button>
                <button class="btn btn-glass" onclick="openPlayerPreview()">
                    👁️ Prévisualiser player
                </button>
            </div>
        </div>
    </div>
</div>

<!-- Modal: Add/Edit Playlist Item -->
<div id="playlist-item-modal" class="modal" style="display: none;">
    <div class="modal-content">
        <div class="modal-header">
            <h3 id="modal-title">Ajouter un média</h3>
            <button class="modal-close" onclick="closePlaylistModal()">✕</button>
        </div>
        <div class="modal-body">
            <div class="form-group">
                <label for="item-url">URL du média</label>
                <input type="text" id="item-url" class="form-control" placeholder="file:///opt/pisignage/content/video.mp4">
                <p class="help-text">file:// pour local, http(s):// pour distant</p>
            </div>
            <div class="form-group">
                <label for="item-fit">Ajustement (object-fit)</label>
                <select id="item-fit" class="form-control">
                    <option value="contain">Contain (conserver proportions)</option>
                    <option value="cover">Cover (remplir l'écran)</option>
                </select>
            </div>
            <div class="form-group">
                <label for="item-duration">Durée (secondes, 0 = auto)</label>
                <input type="number" id="item-duration" class="form-control" value="0" min="0">
            </div>
            <div class="form-group">
                <label class="checkbox-container">
                    <input type="checkbox" id="item-mute">
                    <span>Muet</span>
                </label>
                <label class="checkbox-container">
                    <input type="checkbox" id="item-loop">
                    <span>Boucler cet élément</span>
                </label>
            </div>
        </div>
        <div class="modal-footer">
            <button class="btn btn-glass" onclick="closePlaylistModal()">Annuler</button>
            <button class="btn btn-primary" onclick="savePlaylistItem()">Enregistrer</button>
        </div>
    </div>
</div>

<!-- Modal: Upload Media -->
<div id="upload-modal" class="modal" style="display: none;">
    <div class="modal-content">
        <div class="modal-header">
            <h3>Upload un média</h3>
            <button class="modal-close" onclick="closeUploadModal()">✕</button>
        </div>
        <div class="modal-body">
            <div class="upload-area" id="upload-area">
                <input type="file" id="file-input" accept="video/*" style="display: none;">
                <div class="upload-prompt">
                    <div class="upload-icon">📤</div>
                    <p>Cliquez ou glissez un fichier vidéo</p>
                    <p class="help-text">MP4, WebM, MKV, etc. (max 500MB)</p>
                </div>
            </div>
            <div id="upload-progress" style="display: none;">
                <div class="progress-bar">
                    <div class="progress-fill" id="progress-fill"></div>
                </div>
                <p id="upload-status">Upload en cours...</p>
            </div>
        </div>
    </div>
</div>

<style>
/* Kiosk Control Styles */
.kiosk-mode-controls {
    padding: 20px;
}

.mode-selector {
    margin-bottom: 15px;
}

.switch-container {
    display: flex;
    align-items: center;
    gap: 15px;
    cursor: pointer;
}

.switch-label {
    font-size: 1rem;
    font-weight: 500;
}

.switch-input {
    display: none;
}

.switch-slider {
    position: relative;
    width: 50px;
    height: 26px;
    background: #ccc;
    border-radius: 13px;
    transition: background 0.3s;
}

.switch-slider::before {
    content: '';
    position: absolute;
    width: 22px;
    height: 22px;
    background: white;
    border-radius: 50%;
    top: 2px;
    left: 2px;
    transition: transform 0.3s;
}

.switch-input:checked + .switch-slider {
    background: #4caf50;
}

.switch-input:checked + .switch-slider::before {
    transform: translateX(24px);
}

.help-text {
    font-size: 0.85rem;
    color: #888;
    margin-top: 5px;
}

.playlist-header {
    display: flex;
    gap: 10px;
    margin-bottom: 20px;
    flex-wrap: wrap;
}

.playlist-items {
    min-height: 200px;
    max-height: 500px;
    overflow-y: auto;
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px;
    padding: 15px;
}

.playlist-item {
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px;
    padding: 15px;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    gap: 15px;
}

.playlist-item-drag {
    cursor: move;
    font-size: 1.5rem;
    opacity: 0.5;
}

.playlist-item-content {
    flex: 1;
}

.playlist-item-url {
    font-family: monospace;
    font-size: 0.9rem;
    color: #4caf50;
    margin-bottom: 5px;
}

.playlist-item-meta {
    font-size: 0.85rem;
    color: #888;
}

.playlist-item-actions {
    display: flex;
    gap: 8px;
}

.playlist-item-actions button {
    padding: 5px 10px;
    font-size: 0.85rem;
}

.playlist-settings {
    margin-top: 20px;
    padding: 15px;
    background: rgba(255,255,255,0.05);
    border-radius: 8px;
}

.checkbox-container {
    display: flex;
    align-items: center;
    gap: 10px;
    margin: 10px 0;
    cursor: pointer;
}

.checkbox-container input[type="checkbox"] {
    width: 18px;
    height: 18px;
    cursor: pointer;
}

.form-control.monospace {
    font-family: 'Courier New', monospace;
    font-size: 0.9rem;
}

.kiosk-status {
    padding: 20px;
}

.status-row {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid rgba(255,255,255,0.1);
}

.status-label {
    font-weight: 500;
}

.status-value {
    font-family: monospace;
    color: #4caf50;
}

.status-value.error {
    color: #f44;
}

.auto-refresh-indicator {
    font-size: 0.6rem;
    color: #4caf50;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
}

.action-buttons {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
}

.loading-message {
    text-align: center;
    color: #888;
    padding: 40px 20px;
}

/* Modal Styles */
.modal {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.modal-content {
    background: #1a1a1a;
    border-radius: 12px;
    width: 90%;
    max-width: 600px;
    max-height: 90vh;
    overflow-y: auto;
}

.modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
}

.modal-close {
    background: none;
    border: none;
    color: white;
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    width: 30px;
    height: 30px;
}

.modal-body {
    padding: 20px;
}

.modal-footer {
    padding: 20px;
    border-top: 1px solid rgba(255,255,255,0.1);
    display: flex;
    justify-content: flex-end;
    gap: 10px;
}

.upload-area {
    border: 2px dashed rgba(255,255,255,0.3);
    border-radius: 8px;
    padding: 40px;
    text-align: center;
    cursor: pointer;
    transition: all 0.3s;
}

.upload-area:hover {
    border-color: #4caf50;
    background: rgba(76,175,80,0.1);
}

.upload-icon {
    font-size: 3rem;
    margin-bottom: 10px;
}

.progress-bar {
    width: 100%;
    height: 30px;
    background: rgba(255,255,255,0.1);
    border-radius: 15px;
    overflow: hidden;
    margin-bottom: 10px;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #4caf50, #8bc34a);
    transition: width 0.3s;
    width: 0%;
}
</style>

<script src="/assets/js/kiosk-control.js"></script>

<?php include 'includes/footer.php'; ?>
