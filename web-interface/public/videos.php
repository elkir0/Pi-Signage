<?php
/**
 * Gestion des vidéos Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once dirname(__DIR__) . '/includes/config.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/security.php';

// Vérifier l'authentification
requireAuth();
setSecurityHeaders();

// Traitement des actions
$message = '';
$messageType = '';

// Suppression d'une vidéo
if (isset($_POST['delete']) && isset($_POST['video'])) {
    if (validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $videoPath = VIDEO_DIR . '/' . basename($_POST['video']);
        if (file_exists($videoPath) && is_file($videoPath)) {
            if (unlink($videoPath)) {
                $message = "Vidéo supprimée avec succès";
                $messageType = 'success';
                logActivity('VIDEO_DELETED', basename($_POST['video']));
            } else {
                $message = "Erreur lors de la suppression";
                $messageType = 'error';
            }
        }
    } else {
        $message = "Erreur de sécurité";
        $messageType = 'error';
    }
}

// Upload d'une vidéo
if (isset($_FILES['video']) && $_FILES['video']['error'] === UPLOAD_ERR_OK) {
    if (validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $uploadResult = handleVideoUpload($_FILES['video']);
        if ($uploadResult['success']) {
            $message = $uploadResult['message'];
            $messageType = 'success';
        } else {
            $message = $uploadResult['message'];
            $messageType = 'error';
        }
    }
}

// Obtenir la liste des vidéos
$videos = listVideos();
$diskSpace = checkDiskSpace();

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gestion des Vidéos - Pi Signage</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
    <?php include dirname(__DIR__) . '/templates/navigation.php'; ?>
    
    <main class="container">
        <h1>📹 Gestion des Vidéos</h1>
        
        <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?>"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>
        
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <h2>Upload de Vidéo</h2>
                    <form action="" method="post" enctype="multipart/form-data">
                        <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
                        
                        <div class="form-group">
                            <label for="video">Sélectionner une vidéo</label>
                            <input type="file" id="video" name="video" accept="video/*" required>
                            <small class="form-text">
                                Formats acceptés : <?= implode(', ', ALLOWED_EXTENSIONS) ?>
                                <br>Taille maximale : <?= MAX_UPLOAD_SIZE ?>MB
                            </small>
                        </div>
                        
                        <div id="file-preview"></div>
                        
                        <button type="submit" class="btn btn-success">
                            📤 Uploader la vidéo
                        </button>
                    </form>
                    
                    <hr style="margin: 2rem 0;">
                    
                    <h3>Télécharger depuis YouTube</h3>
                    <p>Utilisez le formulaire en bas de page pour importer une vidéo.</p>
                </div>
            </div>
        </div>
        
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <h2>Vidéos Actuelles</h2>
                    
                    <div class="mb-3">
                        <p>
                            <strong>Espace disque :</strong> 
                            <?= formatFileSize($diskSpace['used']) ?> / <?= formatFileSize($diskSpace['total']) ?>
                            (<?= $diskSpace['percent'] ?>% utilisé)
                        </p>
                        <div class="progress">
                            <div class="progress-bar" style="width: <?= $diskSpace['percent'] ?>%">
                                <?= $diskSpace['percent'] ?>%
                            </div>
                        </div>
                    </div>
                    
                    <?php if (empty($videos)): ?>
                        <p>Aucune vidéo trouvée. Uploadez votre première vidéo !</p>
                    <?php else: ?>
                        <div class="table-responsive">
                            <table class="table">
                                <thead>
                                    <tr>
                                        <th>Nom du fichier</th>
                                        <th>Taille</th>
                                        <th>Date d'ajout</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($videos as $video): ?>
                                        <tr>
                                            <td>
                                                <strong><?= htmlspecialchars($video['name']) ?></strong>
                                                <br>
                                                <small class="text-muted"><?= htmlspecialchars($video['path']) ?></small>
                                            </td>
                                            <td><?= formatFileSize($video['size']) ?></td>
                                            <td><?= date('d/m/Y H:i', $video['modified']) ?></td>
                                            <td>
                                                <form method="post" style="display: inline;" 
                                                      onsubmit="return confirm('Êtes-vous sûr de vouloir supprimer cette vidéo ?');">
                                                    <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
                                                    <input type="hidden" name="video" value="<?= htmlspecialchars($video['name']) ?>">
                                                    <button type="submit" name="delete" class="btn btn-danger btn-sm">
                                                        🗑️ Supprimer
                                                    </button>
                                                </form>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>
        
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <h2>Télécharger depuis YouTube</h2>
                    <p>Pour télécharger vos propres vidéos YouTube :</p>
                    <form id="youtube-form">
                        <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
                        
                        <div class="form-group">
                            <label for="youtube-url">URL YouTube</label>
                            <input type="url" id="youtube-url" name="url" 
                                   placeholder="https://www.youtube.com/watch?v=..." 
                                   class="form-control" required>
                        </div>
                        
                        <button type="button" onclick="piSignage.downloadYouTube()" 
                                class="btn btn-success" id="download-btn">
                            📥 Télécharger
                        </button>
                        
                        <div id="download-progress" style="display: none;"></div>
                    </form>
                </div>
            </div>
        </div>
    </main>
    
    <script src="assets/js/main.js"></script>
</body>
</html>