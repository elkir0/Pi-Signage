<?php
/**
 * Pi Signage Digital - Gestionnaire de fichiers
 * Wrapper pour TinyFileManager
 * @version 2.0.0
 */

session_start();

// Configuration de base
define('FM_ROOT_PATH', '/opt/videos');
define('FM_SELF_URL', $_SERVER['PHP_SELF']);

// Vérifier l'authentification Pi Signage
if (!isset($_SESSION['user']) || !isset($_SESSION['login_time'])) {
    header('Location: index.php');
    exit;
}

// Configuration TinyFileManager
$use_auth = false; // On utilise notre propre authentification
$root_path = FM_ROOT_PATH;
$root_url = '';
$http_host = $_SERVER['HTTP_HOST'];
$iconv_input_encoding = 'UTF-8';
$datetime_format = 'd/m/Y H:i';
$allowed_upload_extensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'];

// Télécharger TinyFileManager si pas présent
$tinyFMPath = __DIR__ . '/includes/tinyfilemanager.php';
if (!file_exists($tinyFMPath)) {
    $tinyFMContent = @file_get_contents('https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php');
    if ($tinyFMContent) {
        // Modifier quelques paramètres
        $tinyFMContent = str_replace('$use_auth = true;', '$use_auth = false;', $tinyFMContent);
        $tinyFMContent = str_replace('$root_path = $_SERVER[\'DOCUMENT_ROOT\'];', '$root_path = \'/opt/videos\';', $tinyFMContent);
        file_put_contents($tinyFMPath, $tinyFMContent);
    } else {
        // Version simplifiée si on ne peut pas télécharger
        ?>
        <!DOCTYPE html>
        <html lang="fr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Pi Signage - Gestionnaire de fichiers</title>
            <link rel="stylesheet" href="assets/css/style.css">
        </head>
        <body>
            <div class="wrapper">
                <nav class="sidebar">
                    <div class="sidebar-header">
                        <h3>Pi Signage</h3>
                        <p class="version">v2.0.0</p>
                    </div>
                    
                    <ul class="sidebar-menu">
                        <li>
                            <a href="dashboard.php">
                                <i class="icon-dashboard"></i>
                                <span>Dashboard</span>
                            </a>
                        </li>
                        <li>
                            <a href="download.php">
                                <i class="icon-download"></i>
                                <span>Télécharger</span>
                            </a>
                        </li>
                        <li class="active">
                            <a href="filemanager.php">
                                <i class="icon-folder"></i>
                                <span>Fichiers</span>
                            </a>
                        </li>
                        <li>
                            <a href="settings.php">
                                <i class="icon-settings"></i>
                                <span>Paramètres</span>
                            </a>
                        </li>
                        <li>
                            <a href="logs.php">
                                <i class="icon-logs"></i>
                                <span>Logs</span>
                            </a>
                        </li>
                    </ul>
                    
                    <div class="sidebar-footer">
                        <a href="logout.php" class="btn btn-sm btn-danger">
                            <i class="icon-logout"></i> Déconnexion
                        </a>
                    </div>
                </nav>
                
                <main class="main-content">
                    <header class="content-header">
                        <h1>Gestionnaire de fichiers</h1>
                    </header>
                    
                    <div class="card">
                        <div class="card-header">
                            <h2>Vidéos dans /opt/videos</h2>
                        </div>
                        <div class="card-body">
                            <?php
                            $videoDir = '/opt/videos';
                            $videos = [];
                            
                            if (is_dir($videoDir)) {
                                $files = scandir($videoDir);
                                foreach ($files as $file) {
                                    if ($file === '.' || $file === '..') continue;
                                    
                                    $extension = strtolower(pathinfo($file, PATHINFO_EXTENSION));
                                    if (in_array($extension, ['mp4', 'avi', 'mkk', 'mov', 'wmv', 'flv', 'webm', 'm4v'])) {
                                        $filepath = $videoDir . '/' . $file;
                                        $videos[] = [
                                            'name' => $file,
                                            'size' => filesize($filepath),
                                            'modified' => filemtime($filepath)
                                        ];
                                    }
                                }
                            }
                            
                            if (empty($videos)):
                            ?>
                            <p class="text-muted">Aucune vidéo trouvée.</p>
                            <?php else: ?>
                            <div class="table-responsive">
                                <table class="table">
                                    <thead>
                                        <tr>
                                            <th>Nom</th>
                                            <th>Taille</th>
                                            <th>Date de modification</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach ($videos as $video): ?>
                                        <tr>
                                            <td>
                                                <i class="icon-play-circle text-primary"></i>
                                                <?= htmlspecialchars($video['name']) ?>
                                            </td>
                                            <td><?= formatBytes($video['size']) ?></td>
                                            <td><?= date('d/m/Y H:i', $video['modified']) ?></td>
                                            <td>
                                                <form method="POST" action="dashboard.php" style="display: inline;">
                                                    <input type="hidden" name="action" value="delete_video">
                                                    <input type="hidden" name="video" value="<?= htmlspecialchars($videoDir . '/' . $video['name']) ?>">
                                                    <button type="submit" class="btn btn-sm btn-danger" onclick="return confirm('Supprimer cette vidéo ?')">
                                                        <i class="icon-trash"></i>
                                                    </button>
                                                </form>
                                            </td>
                                        </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                            <?php endif; ?>
                            
                            <div class="mt-3">
                                <h3>Uploader une vidéo</h3>
                                <form method="POST" enctype="multipart/form-data" id="uploadForm">
                                    <div class="form-group">
                                        <input type="file" name="video" accept=".mp4,.avi,.mkv,.mov,.wmv,.flv,.webm,.m4v" required>
                                    </div>
                                    <button type="submit" class="btn btn-primary">
                                        <i class="icon-upload"></i> Uploader
                                    </button>
                                </form>
                            </div>
                        </div>
                    </div>
                </main>
            </div>
            
            <?php
            // Fonction simple pour formater les octets
            function formatBytes($bytes, $precision = 2) {
                $units = ['B', 'KB', 'MB', 'GB'];
                $bytes = max($bytes, 0);
                $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
                $pow = min($pow, count($units) - 1);
                $bytes /= pow(1024, $pow);
                return round($bytes, $precision) . ' ' . $units[$pow];
            }
            ?>
            
            <script>
            document.getElementById('uploadForm')?.addEventListener('submit', function(e) {
                e.preventDefault();
                
                const fileInput = this.querySelector('input[type="file"]');
                const file = fileInput.files[0];
                
                if (!file) return;
                
                const formData = new FormData();
                formData.append('video', file);
                
                // Créer une barre de progression
                const progressHtml = `
                    <div class="upload-progress mt-2">
                        <div class="progress">
                            <div class="progress-bar progress-bar-animated" style="width: 0%">0%</div>
                        </div>
                        <p class="text-muted">Upload en cours...</p>
                    </div>
                `;
                
                this.insertAdjacentHTML('afterend', progressHtml);
                const progressBar = document.querySelector('.progress-bar');
                
                // Upload avec XMLHttpRequest pour la progression
                const xhr = new XMLHttpRequest();
                
                xhr.upload.addEventListener('progress', (e) => {
                    if (e.lengthComputable) {
                        const percentComplete = (e.loaded / e.total) * 100;
                        progressBar.style.width = percentComplete + '%';
                        progressBar.textContent = Math.round(percentComplete) + '%';
                    }
                });
                
                xhr.addEventListener('load', () => {
                    if (xhr.status === 200) {
                        progressBar.classList.remove('progress-bar-animated');
                        progressBar.classList.add('bg-success');
                        progressBar.textContent = 'Upload terminé !';
                        setTimeout(() => window.location.reload(), 1500);
                    } else {
                        progressBar.classList.add('bg-danger');
                        progressBar.textContent = 'Erreur !';
                    }
                });
                
                xhr.open('POST', '/api/upload.php');
                xhr.send(formData);
            });
            </script>
        </body>
        </html>
        <?php
        exit;
    }
}

// Inclure TinyFileManager
if (file_exists($tinyFMPath)) {
    require $tinyFMPath;
} else {
    die('Erreur : Impossible de charger le gestionnaire de fichiers');
}