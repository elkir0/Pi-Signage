<?php
/**
 * PiSignage Desktop v3.0 - Gestion de la playlist
 */

define('PISIGNAGE_DESKTOP', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

// Vérifier l'authentification
requireAuth();
setSecurityHeaders();

// Préparer les tokens CSRF
startSecureSession();
$csrf_token = generateCSRFToken();

// Traiter les actions POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!verifyCSRFToken($_POST['csrf_token'] ?? '')) {
        $error = 'Token CSRF invalide';
    } else {
        switch ($_POST['action'] ?? '') {
            case 'save_playlist':
                $playlist_data = json_decode($_POST['playlist_data'] ?? '[]', true);
                if (is_array($playlist_data)) {
                    if (savePlaylist($playlist_data)) {
                        $success = 'Playlist sauvegardée avec succès';
                        logAction('Playlist saved');
                    } else {
                        $error = 'Erreur lors de la sauvegarde';
                    }
                } else {
                    $error = 'Données de playlist invalides';
                }
                break;
                
            case 'auto_playlist':
                if (updatePlaylistFromVideos()) {
                    $success = 'Playlist générée automatiquement à partir des vidéos';
                    logAction('Auto playlist generated');
                } else {
                    $error = 'Erreur lors de la génération automatique';
                }
                break;
        }
    }
}

// Obtenir les données
$videos = listVideos();
$playlist = loadPlaylist();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= APP_NAME ?> - Playlist</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <meta name="theme-color" content="#3b82f6">
    <style>
        .playlist-item {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: var(--radius);
            padding: 1rem;
            margin-bottom: 0.5rem;
            cursor: grab;
            transition: all 0.2s ease;
        }
        
        .playlist-item:hover {
            background: var(--bg-tertiary);
            box-shadow: var(--shadow);
        }
        
        .playlist-item.dragging {
            opacity: 0.5;
            transform: rotate(5deg);
        }
        
        .playlist-item.drag-over {
            border-color: var(--accent-primary);
            background: rgba(59, 130, 246, 0.1);
        }
        
        .video-item {
            background: var(--bg-tertiary);
            border: 1px solid var(--border-color);
            border-radius: var(--radius);
            padding: 0.75rem;
            margin-bottom: 0.5rem;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .video-item:hover {
            background: var(--accent-primary);
            color: white;
        }
        
        .video-item.in-playlist {
            background: var(--success);
            color: white;
        }
        
        .duration-input {
            width: 80px;
            padding: 0.25rem 0.5rem;
            border: 1px solid var(--border-color);
            border-radius: 4px;
            background: var(--bg-primary);
            color: var(--text-primary);
        }
        
        .drag-handle {
            cursor: grab;
            color: var(--text-muted);
            margin-right: 0.5rem;
        }
        
        .drag-handle:active {
            cursor: grabbing;
        }
    </style>
</head>
<body>
    <!-- Header -->
    <header class="header">
        <div class="container">
            <div class="header-content">
                <a href="index.php" class="logo">
                    <div class="logo-icon">π</div>
                    <span><?= APP_NAME ?></span>
                </a>
                <div class="header-actions">
                    <button class="theme-toggle" onclick="toggleTheme()" title="Changer de thème">
                        🌙
                    </button>
                    <a href="logout.php" class="btn btn-secondary">Déconnexion</a>
                </div>
            </div>
        </div>
    </header>

    <!-- Navigation -->
    <nav class="nav">
        <div class="container">
            <ul class="nav-list">
                <li class="nav-item">
                    <a href="index.php" class="nav-link">
                        📊 Dashboard
                    </a>
                </li>
                <li class="nav-item">
                    <a href="videos.php" class="nav-link">
                        🎬 Vidéos
                    </a>
                </li>
                <li class="nav-item">
                    <a href="playlist.php" class="nav-link active">
                        📋 Playlist
                    </a>
                </li>
                <li class="nav-item">
                    <a href="api.php" class="nav-link">
                        🔧 API
                    </a>
                </li>
            </ul>
        </div>
    </nav>

    <!-- Main Content -->
    <main class="container" style="margin-top: 2rem; margin-bottom: 2rem;">
        <?php if (isset($success)): ?>
            <div class="toast toast-success fade-in">
                ✅ <?= htmlspecialchars($success) ?>
            </div>
        <?php endif; ?>
        
        <?php if (isset($error)): ?>
            <div class="toast toast-error fade-in">
                ❌ <?= htmlspecialchars($error) ?>
            </div>
        <?php endif; ?>

        <!-- Controls -->
        <div class="card" style="margin-bottom: 2rem;">
            <div class="card-header">
                <h3 class="card-title">🎮 Actions</h3>
            </div>
            <div class="card-body">
                <div style="display: flex; gap: 1rem; flex-wrap: wrap;">
                    <button onclick="savePlaylist()" class="btn btn-primary">
                        💾 Sauvegarder playlist
                    </button>
                    <form method="post" style="display: inline;">
                        <input type="hidden" name="action" value="auto_playlist">
                        <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                        <button type="submit" class="btn btn-secondary">
                            🤖 Génération automatique
                        </button>
                    </form>
                    <button onclick="clearPlaylist()" class="btn btn-warning">
                        🗑️ Vider playlist
                    </button>
                    <button onclick="previewPlaylist()" class="btn btn-primary">
                        👁️ Aperçu
                    </button>
                </div>
            </div>
        </div>

        <div class="grid grid-2">
            <!-- Videos disponibles -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">🎬 Vidéos disponibles (<?= count($videos) ?>)</h3>
                </div>
                <div class="card-body">
                    <?php if (empty($videos)): ?>
                        <div style="text-align: center; padding: 2rem; color: var(--text-muted);">
                            <div style="font-size: 2rem; margin-bottom: 1rem;">📁</div>
                            <div>Aucune vidéo disponible</div>
                            <a href="videos.php" class="btn btn-primary" style="margin-top: 1rem;">
                                📤 Ajouter des vidéos
                            </a>
                        </div>
                    <?php else: ?>
                        <div id="available-videos">
                            <?php 
                            $playlist_files = array_column($playlist, 'file');
                            foreach ($videos as $video): 
                                $in_playlist = in_array($video['name'], $playlist_files);
                            ?>
                                <div class="video-item <?= $in_playlist ? 'in-playlist' : '' ?>" 
                                     data-filename="<?= htmlspecialchars($video['name']) ?>"
                                     onclick="addToPlaylist('<?= htmlspecialchars($video['name']) ?>')">
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <div>
                                            <div style="font-weight: 500;">
                                                <?= htmlspecialchars($video['name']) ?>
                                            </div>
                                            <div style="font-size: 0.75rem; opacity: 0.8;">
                                                <?= formatBytes($video['size']) ?> • <?= strtoupper($video['extension']) ?>
                                            </div>
                                        </div>
                                        <div>
                                            <?= $in_playlist ? '✅' : '➕' ?>
                                        </div>
                                    </div>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <!-- Playlist -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">📋 Playlist (<span id="playlist-count"><?= count($playlist) ?></span>)</h3>
                </div>
                <div class="card-body">
                    <div id="playlist-container">
                        <?php if (empty($playlist)): ?>
                            <div id="empty-playlist" style="text-align: center; padding: 2rem; color: var(--text-muted);">
                                <div style="font-size: 2rem; margin-bottom: 1rem;">📋</div>
                                <div>Playlist vide</div>
                                <div style="font-size: 0.875rem; margin-top: 0.5rem;">
                                    Cliquez sur les vidéos pour les ajouter
                                </div>
                            </div>
                        <?php else: ?>
                            <div id="playlist-items">
                                <?php foreach ($playlist as $index => $item): ?>
                                    <div class="playlist-item" data-filename="<?= htmlspecialchars($item['file']) ?>" draggable="true">
                                        <div style="display: flex; align-items: center; gap: 1rem;">
                                            <span class="drag-handle">≡</span>
                                            <div style="flex: 1;">
                                                <div style="font-weight: 500;">
                                                    <?= htmlspecialchars($item['file']) ?>
                                                </div>
                                                <div style="display: flex; align-items: center; gap: 1rem; margin-top: 0.5rem;">
                                                    <label style="font-size: 0.875rem;">
                                                        Durée:
                                                        <input type="number" class="duration-input" 
                                                               value="<?= $item['duration'] ?? 30 ?>" 
                                                               min="1" max="3600"> sec
                                                    </label>
                                                    <label style="font-size: 0.875rem;">
                                                        <input type="checkbox" <?= ($item['enabled'] ?? true) ? 'checked' : '' ?>>
                                                        Activé
                                                    </label>
                                                </div>
                                            </div>
                                            <button onclick="removeFromPlaylist('<?= htmlspecialchars($item['file']) ?>')" 
                                                    class="btn btn-danger btn-sm">
                                                🗑️
                                            </button>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>

        <!-- Preview Modal -->
        <div id="preview-modal" class="hidden" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.8); z-index: 1000; display: flex; align-items: center; justify-content: center;">
            <div class="card" style="max-width: 600px; max-height: 80vh; margin: 1rem; overflow-y: auto;">
                <div class="card-header">
                    <h3 class="card-title">👁️ Aperçu de la playlist</h3>
                    <button onclick="closePreview()" class="btn btn-secondary btn-sm">✕</button>
                </div>
                <div class="card-body" id="preview-content">
                    <!-- Contenu généré par JavaScript -->
                </div>
            </div>
        </div>
    </main>

    <script src="assets/js/app.js"></script>
    <script>
        let currentPlaylist = <?= json_encode($playlist) ?>;
        let availableVideos = <?= json_encode(array_column($videos, 'name')) ?>;

        // Drag & Drop pour la playlist
        let draggedElement = null;

        function initDragAndDrop() {
            const playlistItems = document.querySelectorAll('.playlist-item');
            
            playlistItems.forEach(item => {
                item.addEventListener('dragstart', function(e) {
                    draggedElement = this;
                    this.classList.add('dragging');
                    e.dataTransfer.effectAllowed = 'move';
                });
                
                item.addEventListener('dragend', function() {
                    this.classList.remove('dragging');
                    draggedElement = null;
                });
                
                item.addEventListener('dragover', function(e) {
                    e.preventDefault();
                    e.dataTransfer.dropEffect = 'move';
                });
                
                item.addEventListener('dragenter', function(e) {
                    e.preventDefault();
                    this.classList.add('drag-over');
                });
                
                item.addEventListener('dragleave', function() {
                    this.classList.remove('drag-over');
                });
                
                item.addEventListener('drop', function(e) {
                    e.preventDefault();
                    this.classList.remove('drag-over');
                    
                    if (draggedElement && draggedElement !== this) {
                        const container = document.getElementById('playlist-items');
                        const afterElement = getDragAfterElement(container, e.clientY);
                        
                        if (afterElement == null) {
                            container.appendChild(draggedElement);
                        } else {
                            container.insertBefore(draggedElement, afterElement);
                        }
                        
                        updatePlaylistOrder();
                    }
                });
            });
        }

        function getDragAfterElement(container, y) {
            const draggableElements = [...container.querySelectorAll('.playlist-item:not(.dragging)')];
            
            return draggableElements.reduce((closest, child) => {
                const box = child.getBoundingClientRect();
                const offset = y - box.top - box.height / 2;
                
                if (offset < 0 && offset > closest.offset) {
                    return { offset: offset, element: child };
                } else {
                    return closest;
                }
            }, { offset: Number.NEGATIVE_INFINITY }).element;
        }

        function addToPlaylist(filename) {
            if (currentPlaylist.find(item => item.file === filename)) {
                return; // Déjà dans la playlist
            }
            
            currentPlaylist.push({
                file: filename,
                duration: 30,
                enabled: true
            });
            
            updatePlaylistDisplay();
            updateVideoItems();
        }

        function removeFromPlaylist(filename) {
            currentPlaylist = currentPlaylist.filter(item => item.file !== filename);
            updatePlaylistDisplay();
            updateVideoItems();
        }

        function updatePlaylistOrder() {
            const items = document.querySelectorAll('.playlist-item');
            const newOrder = [];
            
            items.forEach(item => {
                const filename = item.dataset.filename;
                const playlistItem = currentPlaylist.find(p => p.file === filename);
                if (playlistItem) {
                    // Mettre à jour durée et état
                    const durationInput = item.querySelector('.duration-input');
                    const enabledInput = item.querySelector('input[type="checkbox"]');
                    
                    playlistItem.duration = parseInt(durationInput.value) || 30;
                    playlistItem.enabled = enabledInput.checked;
                    
                    newOrder.push(playlistItem);
                }
            });
            
            currentPlaylist = newOrder;
            updatePlaylistCounter();
        }

        function updatePlaylistDisplay() {
            const container = document.getElementById('playlist-container');
            const emptyMessage = document.getElementById('empty-playlist');
            
            if (currentPlaylist.length === 0) {
                container.innerHTML = `
                    <div id="empty-playlist" style="text-align: center; padding: 2rem; color: var(--text-muted);">
                        <div style="font-size: 2rem; margin-bottom: 1rem;">📋</div>
                        <div>Playlist vide</div>
                        <div style="font-size: 0.875rem; margin-top: 0.5rem;">
                            Cliquez sur les vidéos pour les ajouter
                        </div>
                    </div>
                `;
            } else {
                const playlistHTML = currentPlaylist.map(item => `
                    <div class="playlist-item" data-filename="${item.file}" draggable="true">
                        <div style="display: flex; align-items: center; gap: 1rem;">
                            <span class="drag-handle">≡</span>
                            <div style="flex: 1;">
                                <div style="font-weight: 500;">${item.file}</div>
                                <div style="display: flex; align-items: center; gap: 1rem; margin-top: 0.5rem;">
                                    <label style="font-size: 0.875rem;">
                                        Durée:
                                        <input type="number" class="duration-input" 
                                               value="${item.duration || 30}" 
                                               min="1" max="3600"> sec
                                    </label>
                                    <label style="font-size: 0.875rem;">
                                        <input type="checkbox" ${item.enabled ? 'checked' : ''}>
                                        Activé
                                    </label>
                                </div>
                            </div>
                            <button onclick="removeFromPlaylist('${item.file}')" 
                                    class="btn btn-danger btn-sm">
                                🗑️
                            </button>
                        </div>
                    </div>
                `).join('');
                
                container.innerHTML = `<div id="playlist-items">${playlistHTML}</div>`;
                initDragAndDrop();
            }
            
            updatePlaylistCounter();
        }

        function updateVideoItems() {
            const playlistFiles = currentPlaylist.map(item => item.file);
            document.querySelectorAll('.video-item').forEach(item => {
                const filename = item.dataset.filename;
                const inPlaylist = playlistFiles.includes(filename);
                
                item.className = inPlaylist ? 'video-item in-playlist' : 'video-item';
                item.querySelector('div > div:last-child').textContent = inPlaylist ? '✅' : '➕';
            });
        }

        function updatePlaylistCounter() {
            document.getElementById('playlist-count').textContent = currentPlaylist.length;
        }

        function clearPlaylist() {
            if (confirm('Êtes-vous sûr de vouloir vider la playlist ?')) {
                currentPlaylist = [];
                updatePlaylistDisplay();
                updateVideoItems();
            }
        }

        function savePlaylist() {
            updatePlaylistOrder(); // S'assurer que l'ordre est à jour
            
            const form = document.createElement('form');
            form.method = 'POST';
            form.innerHTML = `
                <input type="hidden" name="action" value="save_playlist">
                <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                <input type="hidden" name="playlist_data" value='${JSON.stringify(currentPlaylist)}'>
            `;
            
            document.body.appendChild(form);
            form.submit();
        }

        function previewPlaylist() {
            const modal = document.getElementById('preview-modal');
            const content = document.getElementById('preview-content');
            
            let totalDuration = 0;
            const enabledItems = currentPlaylist.filter(item => item.enabled);
            
            let html = `
                <div style="margin-bottom: 1rem;">
                    <strong>Résumé:</strong> ${enabledItems.length} vidéos actives sur ${currentPlaylist.length} total
                </div>
            `;
            
            if (enabledItems.length === 0) {
                html += '<div style="color: var(--warning); margin-bottom: 1rem;">⚠️ Aucune vidéo activée dans la playlist</div>';
            }
            
            html += '<div style="max-height: 300px; overflow-y: auto;">';
            
            currentPlaylist.forEach((item, index) => {
                if (item.enabled) totalDuration += item.duration;
                
                html += `
                    <div style="padding: 0.5rem; border: 1px solid var(--border-color); margin-bottom: 0.5rem; border-radius: 4px; ${!item.enabled ? 'opacity: 0.5;' : ''}">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <div>
                                <strong>${index + 1}. ${item.file}</strong>
                                ${!item.enabled ? ' (désactivé)' : ''}
                            </div>
                            <div style="font-size: 0.875rem; color: var(--text-muted);">
                                ${item.duration}s
                            </div>
                        </div>
                    </div>
                `;
            });
            
            html += '</div>';
            
            html += `
                <div style="margin-top: 1rem; padding-top: 1rem; border-top: 1px solid var(--border-color);">
                    <strong>Durée totale:</strong> ${Math.floor(totalDuration / 60)}m ${totalDuration % 60}s
                </div>
            `;
            
            content.innerHTML = html;
            modal.classList.remove('hidden');
            modal.style.display = 'flex';
        }

        function closePreview() {
            const modal = document.getElementById('preview-modal');
            modal.classList.add('hidden');
            modal.style.display = 'none';
        }

        // Initialisation
        document.addEventListener('DOMContentLoaded', function() {
            initDragAndDrop();
            
            // Event listeners pour les inputs
            document.addEventListener('change', function(e) {
                if (e.target.classList.contains('duration-input') || e.target.type === 'checkbox') {
                    updatePlaylistOrder();
                }
            });
            
            // Fermer modal en cliquant en dehors
            document.getElementById('preview-modal').addEventListener('click', function(e) {
                if (e.target === this) {
                    closePreview();
                }
            });
            
            // Supprimer les toasts après 5 secondes
            setTimeout(() => {
                document.querySelectorAll('.toast').forEach(toast => {
                    toast.style.opacity = '0';
                    setTimeout(() => toast.remove(), 300);
                });
            }, 5000);
        });
    </script>
</body>
</html>