/**
 * PiSignage Kiosk Control JavaScript
 * Gestion complète du UI Kiosk Control
 */

// État global
let playlistData = null;
let editingItemIndex = null;
let statusRefreshInterval = null;

// Initialisation
document.addEventListener('DOMContentLoaded', () => {
    console.log('[Kiosk Control] Initializing...');
    loadKioskStatus();
    loadPlaylist();
    loadKioskUrl();
    loadChromiumFlags();
    loadKioskMode();

    // Auto-refresh status toutes les 5 secondes
    startStatusAutoRefresh();

    // Setup event listeners
    setupEventListeners();
});

function setupEventListeners() {
    // Mode switches
    document.getElementById('enable-kiosk').addEventListener('change', (e) => {
        updateKioskMode('enable', e.target.checked);
    });

    document.getElementById('use-chromium-player').addEventListener('change', (e) => {
        updateKioskMode('player', e.target.checked);
    });

    // Upload area drag & drop
    const uploadArea = document.getElementById('upload-area');
    if (uploadArea) {
        uploadArea.addEventListener('click', () => {
            document.getElementById('file-input').click();
        });

        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.style.borderColor = '#4caf50';
        });

        uploadArea.addEventListener('dragleave', (e) => {
            e.preventDefault();
            uploadArea.style.borderColor = '';
        });

        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.style.borderColor = '';
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                handleFileUpload(files[0]);
            }
        });
    }

    const fileInput = document.getElementById('file-input');
    if (fileInput) {
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                handleFileUpload(e.target.files[0]);
            }
        });
    }
}

// === KIOSK MODE ===
async function loadKioskMode() {
    try {
        const response = await fetch('/api/kiosk');
        if (!response.ok) throw new Error('Failed to load kiosk mode');

        const result = await response.json();
        if (result.success && result.data) {
            document.getElementById('enable-kiosk').checked = result.data.enabled !== false;
            document.getElementById('use-chromium-player').checked = result.data.useChromiumPlayer !== false;
        }
    } catch (error) {
        console.error('[Kiosk Mode] Load error:', error);
        showNotification('Erreur chargement mode kiosk', 'error');
    }
}

async function updateKioskMode(type, value) {
    try {
        const endpoint = type === 'enable' ? '/api/kiosk/enable' : '/api/kiosk/mode';
        const body = type === 'enable'
            ? { enabled: value }
            : { useChromiumPlayer: value };

        const response = await fetch(endpoint, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });

        if (!response.ok) throw new Error('Failed to update kiosk mode');

        const result = await response.json();
        if (result.success) {
            showNotification(result.message || 'Mode mis à jour', 'success');
            loadKioskStatus();
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Kiosk Mode] Update error:', error);
        showNotification('Erreur mise à jour mode: ' + error.message, 'error');
    }
}

// === PLAYLIST ===
async function loadPlaylist() {
    try {
        const response = await fetch('/api/playlist');
        if (!response.ok) throw new Error('Failed to load playlist');

        const result = await response.json();
        if (result.success) {
            playlistData = result.data;
            renderPlaylist();

            // Update global settings
            document.getElementById('playlist-autoplay').checked = playlistData.autoplay !== false;
            document.getElementById('playlist-autoloop').checked = playlistData.autoLoop !== false;
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Playlist] Load error:', error);
        document.getElementById('playlist-items').innerHTML =
            '<p class="loading-message error">Erreur chargement playlist</p>';
    }
}

function renderPlaylist() {
    const container = document.getElementById('playlist-items');

    if (!playlistData || !playlistData.items || playlistData.items.length === 0) {
        container.innerHTML = '<p class="loading-message">Aucun média dans la playlist</p>';
        return;
    }

    let html = '';
    playlistData.items.forEach((item, index) => {
        const meta = [];
        if (item.mute) meta.push('🔇 Muet');
        if (item.loop) meta.push('🔁 Loop');
        meta.push('Fit: ' + (item.fit || 'contain'));
        if (item.duration > 0) meta.push('Durée: ' + item.duration + 's');

        html += '<div class="playlist-item" data-index="' + index + '">';
        html += '<div class="playlist-item-drag">☰</div>';
        html += '<div class="playlist-item-content">';
        html += '<div class="playlist-item-url">' + escapeHtml(item.url) + '</div>';
        html += '<div class="playlist-item-meta">' + meta.join(' • ') + '</div>';
        html += '</div>';
        html += '<div class="playlist-item-actions">';
        html += '<button class="btn btn-glass" onclick="editPlaylistItem(' + index + ')">✏️</button>';
        html += '<button class="btn btn-danger" onclick="deletePlaylistItem(' + index + ')">🗑️</button>';
        if (index > 0) {
            html += '<button class="btn btn-glass" onclick="movePlaylistItem(' + index + ', -1)">↑</button>';
        }
        if (index < playlistData.items.length - 1) {
            html += '<button class="btn btn-glass" onclick="movePlaylistItem(' + index + ', 1)">↓</button>';
        }
        html += '</div></div>';
    });

    container.innerHTML = html;
}

function addPlaylistItem() {
    editingItemIndex = null;
    document.getElementById('modal-title').textContent = 'Ajouter un média';
    document.getElementById('item-url').value = '';
    document.getElementById('item-fit').value = 'contain';
    document.getElementById('item-duration').value = '0';
    document.getElementById('item-mute').checked = false;
    document.getElementById('item-loop').checked = false;
    document.getElementById('playlist-item-modal').style.display = 'flex';
}

function editPlaylistItem(index) {
    editingItemIndex = index;
    const item = playlistData.items[index];

    document.getElementById('modal-title').textContent = 'Modifier le média';
    document.getElementById('item-url').value = item.url;
    document.getElementById('item-fit').value = item.fit || 'contain';
    document.getElementById('item-duration').value = item.duration || 0;
    document.getElementById('item-mute').checked = item.mute || false;
    document.getElementById('item-loop').checked = item.loop || false;
    document.getElementById('playlist-item-modal').style.display = 'flex';
}

function savePlaylistItem() {
    const item = {
        url: document.getElementById('item-url').value.trim(),
        fit: document.getElementById('item-fit').value,
        duration: parseInt(document.getElementById('item-duration').value, 10) || 0,
        mute: document.getElementById('item-mute').checked,
        loop: document.getElementById('item-loop').checked
    };

    if (!item.url) {
        alert('URL requise');
        return;
    }

    if (editingItemIndex !== null) {
        playlistData.items[editingItemIndex] = item;
    } else {
        playlistData.items.push(item);
    }

    renderPlaylist();
    closePlaylistModal();
    showNotification('Élément ajouté (pensez à sauvegarder)', 'info');
}

function deletePlaylistItem(index) {
    if (!confirm('Supprimer cet élément ?')) return;

    playlistData.items.splice(index, 1);
    renderPlaylist();
    showNotification('Élément supprimé (pensez à sauvegarder)', 'info');
}

function movePlaylistItem(index, direction) {
    const newIndex = index + direction;
    if (newIndex < 0 || newIndex >= playlistData.items.length) return;

    const temp = playlistData.items[index];
    playlistData.items[index] = playlistData.items[newIndex];
    playlistData.items[newIndex] = temp;

    renderPlaylist();
    showNotification('Ordre modifié (pensez à sauvegarder)', 'info');
}

function closePlaylistModal() {
    document.getElementById('playlist-item-modal').style.display = 'none';
    editingItemIndex = null;
}

async function savePlaylist() {
    if (!playlistData) return;

    // Update global settings
    playlistData.autoplay = document.getElementById('playlist-autoplay').checked;
    playlistData.autoLoop = document.getElementById('playlist-autoloop').checked;
    playlistData.version = (playlistData.version || 0) + 1;

    try {
        const response = await fetch('/api/playlist', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(playlistData)
        });

        if (!response.ok) throw new Error('Failed to save playlist');

        const result = await response.json();
        if (result.success) {
            showNotification('Playlist sauvegardée avec succès', 'success');
            loadPlaylist();
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Playlist] Save error:', error);
        showNotification('Erreur sauvegarde: ' + error.message, 'error');
    }
}

async function validatePlaylist() {
    if (!playlistData) return;

    try {
        const response = await fetch('/api/playlist/validate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(playlistData)
        });

        if (!response.ok) throw new Error('Failed to validate playlist');

        const result = await response.json();
        if (result.success) {
            const data = result.data;
            if (data.allAccessible) {
                showNotification('✅ Playlist valide, tous les médias sont accessibles', 'success');
            } else {
                let message = '⚠️ Playlist valide mais certains médias inaccessibles:\n\n';
                data.urlChecks.forEach(check => {
                    if (!check.accessible) {
                        message += '❌ ' + check.url + '\n   ' + check.message + '\n';
                    }
                });
                alert(message);
            }
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Playlist] Validation error:', error);
        showNotification('Erreur validation: ' + error.message, 'error');
    }
}

async function refreshPlaylist() {
    try {
        const response = await fetch('/api/playlist/refresh', {
            method: 'POST'
        });

        if (!response.ok) throw new Error('Failed to refresh playlist');

        const result = await response.json();
        if (result.success) {
            showNotification('Signal de rechargement envoyé au player', 'success');
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Playlist] Refresh error:', error);
        showNotification('Erreur refresh: ' + error.message, 'error');
    }
}

// === UPLOAD ===
function uploadMedia() {
    document.getElementById('upload-modal').style.display = 'flex';
}

function closeUploadModal() {
    document.getElementById('upload-modal').style.display = 'none';
    document.getElementById('upload-progress').style.display = 'none';
    document.getElementById('upload-area').style.display = 'block';
}

async function handleFileUpload(file) {
    console.log('[Upload] Starting upload:', file.name);

    document.getElementById('upload-area').style.display = 'none';
    document.getElementById('upload-progress').style.display = 'block';

    const formData = new FormData();
    formData.append('file', file);

    try {
        const xhr = new XMLHttpRequest();

        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percent = (e.loaded / e.total) * 100;
                document.getElementById('progress-fill').style.width = percent + '%';
                document.getElementById('upload-status').textContent = 'Upload: ' + Math.round(percent) + '%';
            }
        });

        xhr.addEventListener('load', () => {
            if (xhr.status === 200) {
                const result = JSON.parse(xhr.responseText);
                if (result.success) {
                    showNotification('Fichier uploadé: ' + result.data.filename, 'success');
                    closeUploadModal();

                    // Auto-add to playlist
                    if (confirm('Ajouter ce fichier à la playlist ?')) {
                        playlistData.items.push({
                            url: result.data.url,
                            fit: 'contain',
                            duration: 0,
                            mute: false,
                            loop: false
                        });
                        renderPlaylist();
                        showNotification('Ajouté à la playlist (pensez à sauvegarder)', 'info');
                    }
                } else {
                    throw new Error(result.message);
                }
            } else {
                throw new Error('Upload failed with status ' + xhr.status);
            }
        });

        xhr.addEventListener('error', () => {
            throw new Error('Network error during upload');
        });

        xhr.open('POST', '/api/playlist/upload');
        xhr.send(formData);

    } catch (error) {
        console.error('[Upload] Error:', error);
        showNotification('Erreur upload: ' + error.message, 'error');
        closeUploadModal();
    }
}

// === KIOSK URL ===
async function loadKioskUrl() {
    try {
        const response = await fetch('/api/kiosk/url');
        if (!response.ok) throw new Error('Failed to load kiosk URL');

        const result = await response.json();
        if (result.success && result.data) {
            document.getElementById('kiosk-url').value = result.data.url || '';
        }
    } catch (error) {
        console.error('[Kiosk URL] Load error:', error);
    }
}

async function updateKioskUrl() {
    const url = document.getElementById('kiosk-url').value.trim();

    if (!url) {
        alert('URL requise');
        return;
    }

    try {
        const response = await fetch('/api/kiosk/url', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ url })
        });

        if (!response.ok) throw new Error('Failed to update kiosk URL');

        const result = await response.json();
        if (result.success) {
            showNotification('URL kiosk mise à jour', 'success');
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Kiosk URL] Update error:', error);
        showNotification('Erreur mise à jour URL: ' + error.message, 'error');
    }
}

// === CHROMIUM FLAGS ===
async function loadChromiumFlags() {
    try {
        const response = await fetch('/api/kiosk/flags');
        if (!response.ok) throw new Error('Failed to load flags');

        const result = await response.json();
        if (result.success && result.data) {
            document.getElementById('chromium-flags').value = result.data.flags || '';
        }
    } catch (error) {
        console.error('[Chromium Flags] Load error:', error);
    }
}

async function updateChromiumFlags() {
    const flags = document.getElementById('chromium-flags').value.trim();

    try {
        const response = await fetch('/api/kiosk/flags', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ flags })
        });

        if (!response.ok) throw new Error('Failed to update flags');

        const result = await response.json();
        if (result.success) {
            showNotification('Flags Chromium mis à jour', 'success');
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Chromium Flags] Update error:', error);
        showNotification('Erreur mise à jour flags: ' + error.message, 'error');
    }
}

function resetChromiumFlags() {
    if (!confirm('Réinitialiser aux flags par défaut ?')) return;

    const defaultFlags = '--ozone-platform=wayland\n--enable-features=VaapiVideoDecoder,UseOzonePlatform\n--autoplay-policy=no-user-gesture-required\n--disable-infobars\n--noerrdialogs\n--disable-translate\n--no-first-run\n--fast\n--fast-start\n--disable-features=TranslateUI\n--disk-cache-dir=/dev/null\n--aggressive-cache-discard';

    document.getElementById('chromium-flags').value = defaultFlags;
    showNotification('Flags réinitialisés (pensez à sauvegarder)', 'info');
}

// === STATUS ===
async function loadKioskStatus() {
    try {
        const response = await fetch('/api/kiosk');
        if (!response.ok) throw new Error('Failed to load status');

        const result = await response.json();
        if (result.success && result.data) {
            renderKioskStatus(result.data);
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Status] Load error:', error);
        document.getElementById('kiosk-status').innerHTML =
            '<p class="loading-message error">Erreur chargement statut</p>';
    }
}

function renderKioskStatus(data) {
    let html = '';

    html += '<div class="status-row">';
    html += '<span class="status-label">Mode Kiosk</span>';
    html += '<span class="status-value">' + (data.enabled ? '✅ Activé' : '❌ Désactivé') + '</span>';
    html += '</div>';

    html += '<div class="status-row">';
    html += '<span class="status-label">Chromium Player</span>';
    html += '<span class="status-value">' + (data.useChromiumPlayer ? '✅ Actif' : '⚠️ VLC Fallback') + '</span>';
    html += '</div>';

    html += '<div class="status-row">';
    html += '<span class="status-label">URL Kiosk</span>';
    html += '<span class="status-value">' + escapeHtml(data.url || 'Non définie') + '</span>';
    html += '</div>';

    html += '<div class="status-row">';
    html += '<span class="status-label">Statut Chromium</span>';
    html += '<span class="status-value ' + (data.chromiumRunning ? '' : 'error') + '">';
    html += (data.chromiumRunning ? '🟢 En cours' : '🔴 Arrêté');
    html += '</span></div>';

    if (data.lastUpdate) {
        html += '<div class="status-row">';
        html += '<span class="status-label">Dernière mise à jour</span>';
        html += '<span class="status-value">' + data.lastUpdate + '</span>';
        html += '</div>';
    }

    document.getElementById('kiosk-status').innerHTML = html;
}

function refreshStatus() {
    loadKioskStatus();
    showNotification('Statut actualisé', 'info');
}

function startStatusAutoRefresh() {
    // Refresh toutes les 5 secondes
    statusRefreshInterval = setInterval(() => {
        loadKioskStatus();
    }, 5000);
}

// === ACTIONS ===
async function restartKiosk() {
    if (!confirm('Redémarrer Chromium ?')) return;

    try {
        const response = await fetch('/api/kiosk/restart', {
            method: 'POST'
        });

        if (!response.ok) throw new Error('Failed to restart kiosk');

        const result = await response.json();
        if (result.success) {
            showNotification('Chromium redémarré', 'success');
            setTimeout(() => loadKioskStatus(), 2000);
        } else {
            throw new Error(result.message);
        }
    } catch (error) {
        console.error('[Kiosk] Restart error:', error);
        showNotification('Erreur restart: ' + error.message, 'error');
    }
}

function openPlayerPreview() {
    window.open('/player', '_blank', 'width=1280,height=720');
}

// === UTILS ===
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showNotification(message, type = 'info') {
    console.log('[Notification] ' + type.toUpperCase() + ': ' + message);

    // TODO: Implement proper notification UI
    // Pour l'instant, utiliser console + alert pour erreurs critiques
    if (type === 'error') {
        alert('Erreur: ' + message);
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (statusRefreshInterval) {
        clearInterval(statusRefreshInterval);
    }
});
