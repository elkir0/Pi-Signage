<?php
/**
 * PiSignage Desktop v3.0 - Gestion des vidéos
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
            case 'upload':
                if (isset($_FILES['video'])) {
                    $result = handleVideoUpload($_FILES['video']);
                    if ($result['success']) {
                        $success = $result['message'];
                        logAction('Video uploaded', $result['filename'] ?? '');
                    } else {
                        $error = $result['message'];
                    }
                }
                break;
                
            case 'delete':
                $filename = $_POST['filename'] ?? '';
                $result = deleteVideo($filename);
                if ($result['success']) {
                    $success = $result['message'];
                    logAction('Video deleted', $filename);
                } else {
                    $error = $result['message'];
                }
                break;
                
            case 'youtube':
                $url = $_POST['youtube_url'] ?? '';
                if (!empty($url)) {
                    $result = downloadYouTubeVideo($url);
                    if ($result['success']) {
                        $success = $result['message'];
                        logAction('YouTube video downloaded', $url);
                    } else {
                        $error = $result['message'];
                    }
                }
                break;
        }
    }
}

// Obtenir la liste des vidéos
$videos = listVideos();
$systemInfo = getSystemInfo();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= APP_NAME ?> - Gestion des vidéos</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <meta name="theme-color" content="#3b82f6">
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
                    <a href="videos.php" class="nav-link active">
                        🎬 Vidéos
                    </a>
                </li>
                <li class="nav-item">
                    <a href="playlist.php" class="nav-link">
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

        <!-- Upload Section -->
        <div class="grid grid-2" style="margin-bottom: 2rem;">
            <!-- Upload Local -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">📤 Upload vidéo</h3>
                </div>
                <div class="card-body">
                    <form method="post" enctype="multipart/form-data" id="upload-form">
                        <input type="hidden" name="action" value="upload">
                        <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                        
                        <div class="upload-area" id="upload-area">
                            <div class="upload-icon">📁</div>
                            <div>
                                <strong>Glisser-déposer ou cliquer pour sélectionner</strong><br>
                                <span style="font-size: 0.875rem; color: var(--text-muted);">
                                    Max <?= MAX_UPLOAD_SIZE ?>MB - Formats: <?= implode(', ', ALLOWED_EXTENSIONS) ?>
                                </span>
                            </div>
                            <input type="file" name="video" id="video-input" accept=".<?= implode(',.'‚ ALLOWED_EXTENSIONS) ?>" style="display: none;">
                        </div>
                        
                        <div id="upload-progress" class="hidden" style="margin-top: 1rem;">
                            <div class="progress">
                                <div class="progress-bar" id="upload-progress-bar" style="width: 0%"></div>
                            </div>
                            <div style="text-align: center; margin-top: 0.5rem; font-size: 0.875rem;" id="upload-status">
                                Téléchargement en cours...
                            </div>
                        </div>
                        
                        <button type="submit" class="btn btn-primary w-full" style="margin-top: 1rem;" id="upload-btn">
                            📤 Uploader
                        </button>
                    </form>
                </div>
            </div>

            <!-- YouTube Download -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">📺 YouTube</h3>
                </div>
                <div class="card-body">
                    <form method="post" id="youtube-form">
                        <input type="hidden" name="action" value="youtube">
                        <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                        
                        <div class="form-group">
                            <label for="youtube_url" class="form-label">URL YouTube</label>
                            <input type="url" name="youtube_url" id="youtube_url" class="form-input" 
                                   placeholder="https://youtube.com/watch?v=..." required>
                        </div>
                        
                        <div id="youtube-progress" class="hidden" style="margin-bottom: 1rem;">
                            <div class="progress">
                                <div class="progress-bar spin" style="width: 100%; background: linear-gradient(45deg, var(--accent-primary), transparent, var(--accent-primary))"></div>
                            </div>
                            <div style="text-align: center; margin-top: 0.5rem; font-size: 0.875rem;">
                                Téléchargement depuis YouTube...
                            </div>
                        </div>
                        
                        <button type="submit" class="btn btn-primary w-full" id="youtube-btn">
                            📺 Télécharger
                        </button>
                    </form>
                </div>
            </div>
        </div>

        <!-- Storage Info -->
        <div class="card" style="margin-bottom: 2rem;">
            <div class="card-header">
                <h3 class="card-title">💽 Espace de stockage</h3>
            </div>
            <div class="card-body">
                <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
                    <span><?= formatBytes($systemInfo['disk']['used'] ?? 0) ?> utilisés</span>
                    <span><?= formatBytes($systemInfo['disk']['free'] ?? 0) ?> libres</span>
                </div>
                <div class="progress">
                    <div class="progress-bar" style="width: <?= $systemInfo['disk']['percent'] ?? 0 ?>%"></div>
                </div>
                <div style="text-align: center; margin-top: 0.5rem; font-size: 0.875rem; color: var(--text-muted);">
                    <?= $systemInfo['disk']['percent'] ?? 0 ?>% utilisé sur <?= formatBytes($systemInfo['disk']['total'] ?? 0) ?>
                </div>
            </div>
        </div>

        <!-- Videos List -->
        <div class="card">
            <div class="card-header">
                <h3 class="card-title">🎬 Vidéos (<?= count($videos) ?>)</h3>
                <button onclick="location.reload()" class="btn btn-secondary btn-sm">
                    🔄 Actualiser
                </button>
            </div>
            <div class="card-body">
                <?php if (empty($videos)): ?>
                    <div style="text-align: center; padding: 2rem; color: var(--text-muted);">
                        <div style="font-size: 3rem; margin-bottom: 1rem;">📁</div>
                        <div>Aucune vidéo trouvée</div>
                        <div style="font-size: 0.875rem; margin-top: 0.5rem;">
                            Uploadez des vidéos ou téléchargez depuis YouTube
                        </div>
                    </div>
                <?php else: ?>
                    <div class="table-container" style="overflow-x: auto;">
                        <table class="table">
                            <thead>
                                <tr>
                                    <th>📁 Nom</th>
                                    <th>📊 Taille</th>
                                    <th>📅 Date</th>
                                    <th>🔧 Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($videos as $video): ?>
                                    <tr>
                                        <td>
                                            <div style="font-weight: 500;">
                                                <?= htmlspecialchars($video['name']) ?>
                                            </div>
                                            <div style="font-size: 0.75rem; color: var(--text-muted);">
                                                <?= strtoupper($video['extension']) ?>
                                            </div>
                                        </td>
                                        <td><?= formatBytes($video['size']) ?></td>
                                        <td>
                                            <div><?= date('d/m/Y', $video['modified']) ?></div>
                                            <div style="font-size: 0.75rem; color: var(--text-muted);">
                                                <?= date('H:i', $video['modified']) ?>
                                            </div>
                                        </td>
                                        <td>
                                            <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                                                <button onclick="deleteVideo('<?= htmlspecialchars($video['name']) ?>')" 
                                                        class="btn btn-danger btn-sm">
                                                    🗑️ Supprimer
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </main>

    <!-- Delete Confirmation Modal -->
    <div id="delete-modal" class="hidden" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; display: flex; align-items: center; justify-content: center;">
        <div class="card" style="max-width: 400px; margin: 1rem;">
            <div class="card-header">
                <h3 class="card-title">⚠️ Confirmer la suppression</h3>
            </div>
            <div class="card-body">
                <p>Êtes-vous sûr de vouloir supprimer cette vidéo ?</p>
                <p><strong id="delete-filename"></strong></p>
                <div style="display: flex; gap: 1rem; margin-top: 1.5rem;">
                    <button onclick="cancelDelete()" class="btn btn-secondary">Annuler</button>
                    <form method="post" style="flex: 1;" id="delete-form">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                        <input type="hidden" name="filename" id="delete-filename-input">
                        <button type="submit" class="btn btn-danger w-full">🗑️ Supprimer</button>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script src="assets/js/app.js"></script>
    <script>
        // Upload drag & drop
        const uploadArea = document.getElementById('upload-area');
        const videoInput = document.getElementById('video-input');
        const uploadForm = document.getElementById('upload-form');
        const uploadProgress = document.getElementById('upload-progress');
        const uploadBtn = document.getElementById('upload-btn');

        uploadArea.addEventListener('click', () => videoInput.click());
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('dragover');
        });
        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('dragover');
        });
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('dragover');
            if (e.dataTransfer.files.length > 0) {
                videoInput.files = e.dataTransfer.files;
                updateUploadArea();
            }
        });

        videoInput.addEventListener('change', updateUploadArea);

        function updateUploadArea() {
            if (videoInput.files.length > 0) {
                const file = videoInput.files[0];
                uploadArea.innerHTML = `
                    <div class="upload-icon">✅</div>
                    <div>
                        <strong>${file.name}</strong><br>
                        <span style="font-size: 0.875rem; color: var(--text-muted);">
                            ${(file.size / 1024 / 1024).toFixed(2)} MB
                        </span>
                    </div>
                `;
            }
        }

        // YouTube form
        const youtubeForm = document.getElementById('youtube-form');
        const youtubeProgress = document.getElementById('youtube-progress');
        const youtubeBtn = document.getElementById('youtube-btn');

        youtubeForm.addEventListener('submit', function(e) {
            youtubeProgress.classList.remove('hidden');
            youtubeBtn.disabled = true;
            youtubeBtn.textContent = '⏳ Téléchargement...';
        });

        uploadForm.addEventListener('submit', function(e) {
            if (videoInput.files.length > 0) {
                uploadProgress.classList.remove('hidden');
                uploadBtn.disabled = true;
                uploadBtn.textContent = '⏳ Upload...';
            }
        });

        // Delete modal
        let deleteModal = document.getElementById('delete-modal');
        let deleteFilenameSpan = document.getElementById('delete-filename');
        let deleteFilenameInput = document.getElementById('delete-filename-input');

        function deleteVideo(filename) {
            deleteFilenameSpan.textContent = filename;
            deleteFilenameInput.value = filename;
            deleteModal.classList.remove('hidden');
            deleteModal.style.display = 'flex';
        }

        function cancelDelete() {
            deleteModal.classList.add('hidden');
            deleteModal.style.display = 'none';
        }

        // Fermer modal en cliquant en dehors
        deleteModal.addEventListener('click', function(e) {
            if (e.target === deleteModal) {
                cancelDelete();
            }
        });

        // Initialisation
        document.addEventListener('DOMContentLoaded', function() {
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