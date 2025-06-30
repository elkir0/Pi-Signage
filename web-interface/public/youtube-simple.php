<?php
/**
 * Page de téléchargement YouTube simplifiée
 */

define('PI_SIGNAGE_WEB', true);
require_once dirname(__DIR__) . '/includes/config.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/security.php';

requireAuth();
setSecurityHeaders();

$message = '';
$messageType = '';

// Traitement du formulaire
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['url'])) {
    if (validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $url = $_POST['url'] ?? '';
        $customTitle = $_POST['title'] ?? '';
        
        // Validation de l'URL
        if (!filter_var($url, FILTER_VALIDATE_URL) || !preg_match('/^https?:\/\/(www\.)?(youtube\.com|youtu\.be)\//', $url)) {
            $message = "URL YouTube invalide";
            $messageType = 'error';
        } else {
            // Générer un nom de fichier
            $filename = $customTitle ? preg_replace('/[^a-zA-Z0-9._-]/', '_', $customTitle) : 'video_' . time();
            $output_path = VIDEO_DIR . '/' . $filename . '.mp4';
            
            // Commande yt-dlp
            $cmd = sprintf(
                '%s -f "best[ext=mp4]/best" -o %s --no-playlist %s',
                escapeshellcmd(YTDLP_BIN),
                escapeshellarg($output_path),
                escapeshellarg($url)
            );

            if (DISPLAY_MODE === 'chromium') {
                $cmd .= ' --recode-video mp4 --postprocessor-args "-c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart"';
            }

            $cmd .= ' 2>&1';
            
            // Exécuter (avec timeout de 5 minutes)
            set_time_limit(300);
            $output = shell_exec($cmd);
            
            // Vérifier le résultat
            if (file_exists($output_path) && filesize($output_path) > 0) {
                $filesize = filesize($output_path);
                logActivity("VIDEO_DOWNLOAD_SUCCESS", basename($output_path));
                $message = "Vidéo téléchargée avec succès : " . basename($output_path) . " (" . formatFileSize($filesize) . ")";
                $messageType = 'success';
            } else {
                logActivity("VIDEO_DOWNLOAD_FAILED", $url);
                $message = "Échec du téléchargement. Vérifiez l'URL et réessayez.";
                $messageType = 'error';
                
                // Si mode debug, afficher la sortie
                if (defined('DEBUG_MODE') && DEBUG_MODE) {
                    $message .= "<br><pre>" . htmlspecialchars($output) . "</pre>";
                }
            }
        }
    } else {
        $message = "Erreur de sécurité";
        $messageType = 'error';
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Téléchargement YouTube - Pi Signage</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
    <?php include dirname(__DIR__) . '/templates/navigation.php'; ?>
    
    <main class="container">
        <h1>📥 Téléchargement YouTube</h1>
        
        <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?>"><?= $message ?></div>
        <?php endif; ?>
        
        <div class="card">
            <h2>Télécharger une vidéo YouTube</h2>
            
            <form method="post" action="">
                <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
                
                <div class="form-group">
                    <label for="url">URL de la vidéo YouTube</label>
                    <input type="url" 
                           id="url" 
                           name="url" 
                           placeholder="https://www.youtube.com/watch?v=..." 
                           required 
                           class="form-control"
                           value="<?= htmlspecialchars($_POST['url'] ?? '') ?>">
                </div>
                
                <div class="form-group">
                    <label for="title">Titre personnalisé (optionnel)</label>
                    <input type="text" 
                           id="title" 
                           name="title" 
                           placeholder="Laissez vide pour utiliser le titre YouTube"
                           class="form-control"
                           value="<?= htmlspecialchars($_POST['title'] ?? '') ?>">
                </div>
                
                <button type="submit" class="btn btn-success" id="downloadBtn">
                    📥 Télécharger la vidéo
                </button>
                
                <p style="margin-top: 1rem; color: #666;">
                    <small>⏱️ Le téléchargement peut prendre plusieurs minutes selon la taille de la vidéo.</small>
                </p>
            </form>
        </div>
        
        <div style="margin-top: 2rem; text-align: center;">
            <a href="videos.php" class="btn btn-secondary">← Retour à la gestion des vidéos</a>
        </div>
    </main>
    
    <script>
    // Désactiver le bouton pendant le téléchargement
    document.querySelector('form').addEventListener('submit', function() {
        const btn = document.getElementById('downloadBtn');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner"></span> Téléchargement en cours...';
    });
    </script>
    
    <style>
    .spinner {
        display: inline-block;
        width: 16px;
        height: 16px;
        border: 2px solid rgba(255,255,255,.3);
        border-radius: 50%;
        border-top-color: #fff;
        animation: spin 1s ease-in-out infinite;
    }
    
    @keyframes spin {
        to { transform: rotate(360deg); }
    }
    </style>
</body>
</html>