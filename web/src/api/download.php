<?php
/**
 * Pi Signage Digital - Téléchargement YouTube
 * @version 2.0.0
 */

session_start();
require_once 'includes/config.php';
require_once 'includes/functions.php';
require_once 'includes/session.php';

// Vérifier l'authentification
checkAuth();

// Traitement du formulaire
$message = '';
$messageType = '';
$isDownloading = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['youtube_url'])) {
    // Vérifier le token CSRF
    checkCSRF($_POST['csrf_token'] ?? '');
    
    // Limiter le taux de téléchargements
    rateLimit('youtube_download', 10, 3600); // 10 téléchargements par heure
    
    $url = trim($_POST['youtube_url']);
    $quality = $_POST['quality'] ?? '720p';
    
    if (empty($url)) {
        $message = 'Veuillez entrer une URL YouTube';
        $messageType = 'error';
    } else {
        // Créer un fichier de progression
        $progressFile = TEMP_DIR . '/download_' . md5($url) . '.progress';
        file_put_contents($progressFile, json_encode(['status' => 'starting', 'progress' => 0]));
        
        // Lancer le téléchargement en arrière-plan
        $cmd = sprintf(
            'nohup %s -f "%s" -o "%s/%%(title)s.%%(ext)s" --restrict-filenames --no-playlist --no-overwrites --newline "%s" > %s 2>&1 &',
            YTDLP_BIN,
            match($quality) {
                '480p' => 'best[height<=480]/best',
                '720p' => 'best[height<=720]/best',
                '1080p' => 'best[height<=1080]/best',
                default => 'best'
            },
            VIDEO_DIR,
            escapeshellarg($url),
            $progressFile . '.log'
        );
        
        exec($cmd);
        
        $message = 'Téléchargement démarré. La vidéo sera disponible dans quelques minutes.';
        $messageType = 'success';
        $isDownloading = true;
        
        // Log l'action
        logAction('YouTube download', "URL: $url, Quality: $quality");
    }
}

// Générer le token CSRF
$csrfToken = generateCSRF();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage - Télécharger</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="icon" type="image/png" href="assets/img/favicon.png">
</head>
<body>
    <div class="wrapper">
        <!-- Sidebar -->
        <nav class="sidebar">
            <div class="sidebar-header">
                <h3>Pi Signage</h3>
                <p class="version">v<?= VERSION ?></p>
            </div>
            
            <ul class="sidebar-menu">
                <li>
                    <a href="dashboard.php">
                        <i class="icon-dashboard"></i>
                        <span>Dashboard</span>
                    </a>
                </li>
                <li class="active">
                    <a href="download.php">
                        <i class="icon-download"></i>
                        <span>Télécharger</span>
                    </a>
                </li>
                <li>
                    <a href="filemanager.php" target="_blank">
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
        
        <!-- Main Content -->
        <main class="main-content">
            <header class="content-header">
                <h1>Télécharger une vidéo</h1>
            </header>
            
            <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?> alert-dismissible">
                <?= htmlspecialchars($message) ?>
                <button type="button" class="close" data-dismiss="alert">&times;</button>
            </div>
            <?php endif; ?>
            
            <!-- Formulaire de téléchargement -->
            <div class="card">
                <div class="card-header">
                    <h2>Télécharger depuis YouTube</h2>
                </div>
                <div class="card-body">
                    <div class="info-box">
                        <i class="icon-info-circle"></i>
                        <p>Téléchargez uniquement <strong>vos propres vidéos</strong> ou des vidéos dont vous avez les droits.</p>
                    </div>
                    
                    <form method="POST" id="downloadForm">
                        <input type="hidden" name="csrf_token" value="<?= $csrfToken ?>">
                        
                        <div class="form-group">
                            <label for="youtube_url">URL YouTube</label>
                            <input type="url" 
                                   id="youtube_url" 
                                   name="youtube_url" 
                                   class="form-control" 
                                   placeholder="https://www.youtube.com/watch?v=..." 
                                   required>
                            <small class="form-text text-muted">
                                Formats supportés : YouTube, YouTube Shorts
                            </small>
                        </div>
                        
                        <div class="form-group">
                            <label for="quality">Qualité</label>
                            <select id="quality" name="quality" class="form-control">
                                <option value="480p">480p (Économie d'espace)</option>
                                <option value="720p" selected>720p (Recommandé)</option>
                                <option value="1080p">1080p (Haute qualité)</option>
                            </select>
                        </div>
                        
                        <button type="submit" class="btn btn-primary" id="downloadBtn">
                            <i class="icon-download"></i> Télécharger
                        </button>
                    </form>
                    
                    <div id="downloadProgress" style="display: none;">
                        <div class="progress">
                            <div class="progress-bar progress-bar-animated" id="progressBar" style="width: 0%">0%</div>
                        </div>
                        <p class="text-muted mt-2" id="progressText">Préparation du téléchargement...</p>
                    </div>
                </div>
            </div>
            
            <!-- Instructions -->
            <div class="card">
                <div class="card-header">
                    <h2>Instructions</h2>
                </div>
                <div class="card-body">
                    <ol>
                        <li>Copiez l'URL de votre vidéo YouTube</li>
                        <li>Collez-la dans le champ ci-dessus</li>
                        <li>Sélectionnez la qualité souhaitée</li>
                        <li>Cliquez sur Télécharger</li>
                        <li>La vidéo sera automatiquement ajoutée à la playlist</li>
                    </ol>
                    
                    <div class="alert alert-info">
                        <strong>Note :</strong> Le téléchargement peut prendre plusieurs minutes selon la taille de la vidéo et votre connexion internet.
                    </div>
                </div>
            </div>
            
            <!-- Téléchargements récents -->
            <div class="card">
                <div class="card-header">
                    <h2>Téléchargements récents</h2>
                </div>
                <div class="card-body">
                    <?php
                    $recentVideos = array_slice(getVideoList(), 0, 5);
                    if (empty($recentVideos)):
                    ?>
                    <p class="text-muted">Aucun téléchargement récent</p>
                    <?php else: ?>
                    <ul class="recent-downloads">
                        <?php foreach ($recentVideos as $video): ?>
                        <li>
                            <i class="icon-check-circle text-success"></i>
                            <span><?= htmlspecialchars($video['name']) ?></span>
                            <small class="text-muted">
                                (<?= formatBytes($video['size']) ?> - <?= date('d/m H:i', $video['modified']) ?>)
                            </small>
                        </li>
                        <?php endforeach; ?>
                    </ul>
                    <?php endif; ?>
                </div>
            </div>
        </main>
    </div>
    
    <script src="assets/js/main.js"></script>
    <script>
    // Gestion du formulaire de téléchargement
    document.getElementById('downloadForm').addEventListener('submit', function(e) {
        const btn = document.getElementById('downloadBtn');
        const progress = document.getElementById('downloadProgress');
        
        btn.disabled = true;
        btn.innerHTML = '<i class="icon-spinner spin"></i> Téléchargement en cours...';
        
        // Afficher la barre de progression (simulée pour l'instant)
        setTimeout(() => {
            progress.style.display = 'block';
            simulateProgress();
        }, 500);
    });
    
    function simulateProgress() {
        let progress = 0;
        const bar = document.getElementById('progressBar');
        const text = document.getElementById('progressText');
        
        const interval = setInterval(() => {
            progress += Math.random() * 10;
            if (progress > 90) progress = 90; // Ne pas aller jusqu'à 100%
            
            bar.style.width = progress + '%';
            bar.textContent = Math.round(progress) + '%';
            
            if (progress < 20) {
                text.textContent = 'Connexion à YouTube...';
            } else if (progress < 50) {
                text.textContent = 'Téléchargement en cours...';
            } else {
                text.textContent = 'Finalisation...';
            }
        }, 1000);
        
        // Arrêter après 30 secondes
        setTimeout(() => {
            clearInterval(interval);
            bar.style.width = '100%';
            bar.textContent = '100%';
            text.textContent = 'Téléchargement terminé ! Redirection...';
            
            setTimeout(() => {
                window.location.href = 'dashboard.php';
            }, 2000);
        }, 30000);
    }
    </script>
</body>
</html>