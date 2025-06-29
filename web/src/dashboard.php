<?php
/**
 * Pi Signage Digital - Dashboard
 * Interface principale de gestion
 * @version 2.0.0
 */

session_start();
require_once 'includes/config.php';
require_once 'includes/functions.php';
require_once 'includes/session.php';

// Vérifier l'authentification
checkAuth();

// Récupérer les informations système
$systemInfo = getSystemInfo();
$videos = getVideoList();
$diskUsage = getDiskUsage();
$services = getServicesStatus();

// Traitement des actions
$message = '';
$messageType = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        switch ($_POST['action']) {
            case 'restart_vlc':
                if (restartVLC()) {
                    $message = 'VLC redémarré avec succès';
                    $messageType = 'success';
                } else {
                    $message = 'Erreur lors du redémarrage de VLC';
                    $messageType = 'error';
                }
                break;
                
            case 'delete_video':
                $videoFile = $_POST['video'] ?? '';
                if (deleteVideo($videoFile)) {
                    $message = 'Vidéo supprimée avec succès';
                    $messageType = 'success';
                } else {
                    $message = 'Erreur lors de la suppression';
                    $messageType = 'error';
                }
                break;
                
            case 'sync_now':
                if (syncVideos()) {
                    $message = 'Synchronisation lancée';
                    $messageType = 'success';
                } else {
                    $message = 'Erreur lors de la synchronisation';
                    $messageType = 'error';
                }
                break;
        }
        
        // Recharger les infos après action
        $videos = getVideoList();
        $services = getServicesStatus();
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage - Dashboard</title>
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
                <li class="active">
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
                <h1>Dashboard</h1>
                <div class="header-actions">
                    <span class="status-indicator <?= $services['vlc'] ? 'online' : 'offline' ?>">
                        VLC: <?= $services['vlc'] ? 'Actif' : 'Inactif' ?>
                    </span>
                    <span class="hostname"><?= gethostname() ?></span>
                </div>
            </header>
            
            <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?> alert-dismissible">
                <?= htmlspecialchars($message) ?>
                <button type="button" class="close" data-dismiss="alert">&times;</button>
            </div>
            <?php endif; ?>
            
            <!-- Stats Cards -->
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-icon bg-primary">
                        <i class="icon-video"></i>
                    </div>
                    <div class="stat-content">
                        <h3><?= count($videos) ?></h3>
                        <p>Vidéos</p>
                    </div>
                </div>
                
                <div class="stat-card">
                    <div class="stat-icon bg-success">
                        <i class="icon-cpu"></i>
                    </div>
                    <div class="stat-content">
                        <h3><?= $systemInfo['cpu_usage'] ?>%</h3>
                        <p>CPU</p>
                    </div>
                </div>
                
                <div class="stat-card">
                    <div class="stat-icon bg-warning">
                        <i class="icon-memory"></i>
                    </div>
                    <div class="stat-content">
                        <h3><?= $systemInfo['memory_usage'] ?>%</h3>
                        <p>Mémoire</p>
                    </div>
                </div>
                
                <div class="stat-card">
                    <div class="stat-icon bg-danger">
                        <i class="icon-thermometer"></i>
                    </div>
                    <div class="stat-content">
                        <h3><?= $systemInfo['temperature'] ?>°C</h3>
                        <p>Température</p>
                    </div>
                </div>
            </div>
            
            <!-- Actions rapides -->
            <div class="card">
                <div class="card-header">
                    <h2>Actions rapides</h2>
                </div>
                <div class="card-body">
                    <div class="action-buttons">
                        <form method="POST" style="display: inline-block;">
                            <input type="hidden" name="action" value="restart_vlc">
                            <button type="submit" class="btn btn-primary">
                                <i class="icon-refresh"></i> Redémarrer VLC
                            </button>
                        </form>
                        
                        <form method="POST" style="display: inline-block;">
                            <input type="hidden" name="action" value="sync_now">
                            <button type="submit" class="btn btn-secondary">
                                <i class="icon-sync"></i> Synchroniser maintenant
                            </button>
                        </form>
                        
                        <a href="download.php" class="btn btn-success">
                            <i class="icon-plus"></i> Ajouter vidéo
                        </a>
                    </div>
                </div>
            </div>
            
            <!-- Liste des vidéos -->
            <div class="card">
                <div class="card-header">
                    <h2>Vidéos actuelles</h2>
                    <div class="card-tools">
                        <span class="badge"><?= formatBytes(array_sum(array_column($videos, 'size'))) ?></span>
                    </div>
                </div>
                <div class="card-body">
                    <?php if (empty($videos)): ?>
                    <div class="empty-state">
                        <i class="icon-video-off"></i>
                        <p>Aucune vidéo trouvée</p>
                        <a href="download.php" class="btn btn-primary">
                            Ajouter des vidéos
                        </a>
                    </div>
                    <?php else: ?>
                    <div class="table-responsive">
                        <table class="table">
                            <thead>
                                <tr>
                                    <th>Nom</th>
                                    <th>Taille</th>
                                    <th>Date d'ajout</th>
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
                                        <form method="POST" style="display: inline;" 
                                              onsubmit="return confirm('Supprimer cette vidéo ?');">
                                            <input type="hidden" name="action" value="delete_video">
                                            <input type="hidden" name="video" value="<?= htmlspecialchars($video['path']) ?>">
                                            <button type="submit" class="btn btn-sm btn-danger">
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
                </div>
            </div>
            
            <!-- État du système -->
            <div class="card">
                <div class="card-header">
                    <h2>État du système</h2>
                </div>
                <div class="card-body">
                    <div class="system-info">
                        <div class="info-row">
                            <span class="label">Uptime:</span>
                            <span class="value"><?= $systemInfo['uptime'] ?></span>
                        </div>
                        <div class="info-row">
                            <span class="label">Espace disque:</span>
                            <div class="progress">
                                <div class="progress-bar" style="width: <?= $diskUsage['percent'] ?>%">
                                    <?= $diskUsage['percent'] ?>%
                                </div>
                            </div>
                            <span class="text-muted">
                                <?= formatBytes($diskUsage['used']) ?> / <?= formatBytes($diskUsage['total']) ?>
                            </span>
                        </div>
                        <div class="info-row">
                            <span class="label">Services:</span>
                            <span class="value">
                                <?php foreach ($services as $service => $status): ?>
                                <span class="badge badge-<?= $status ? 'success' : 'danger' ?>">
                                    <?= $service ?>
                                </span>
                                <?php endforeach; ?>
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </main>
    </div>
    
    <script src="assets/js/main.js"></script>
    <script>
    // Auto-refresh toutes les 30 secondes
    setTimeout(() => location.reload(), 30000);
    </script>
</body>
</html>