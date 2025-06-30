<?php
/**
 * Tableau de bord Pi Signage
 */

define('PI_SIGNAGE_WEB', true);
require_once dirname(__DIR__) . '/includes/config.php';
require_once dirname(__DIR__) . '/includes/auth.php';
require_once dirname(__DIR__) . '/includes/functions.php';
require_once dirname(__DIR__) . '/includes/security.php';

// Vérifier l'authentification
requireAuth();
setSecurityHeaders();

// Obtenir les informations système
$systemInfo = getSystemInfo();
$diskSpace = checkDiskSpace();
$vlcStatus = checkServiceStatus('vlc-signage.service');
$videos = listVideos();
$videoCount = count($videos);

// Préparer le token CSRF pour les actions
startSecureSession();
$csrf_token = generateCSRFToken();
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage - Tableau de bord</title>
    <link rel="stylesheet" href="assets/css/dashboard.css">
</head>
<body>
    <?php include '../templates/navigation.php'; ?>
    
    <div class="container">
        <header class="page-header">
            <h1>Tableau de bord</h1>
            <div class="header-actions">
                <span class="status-indicator <?= $vlcStatus['active'] ? 'active' : 'inactive' ?>">
                    VLC: <?= $vlcStatus['active'] ? 'Actif' : 'Inactif' ?>
                </span>
            </div>
        </header>
        
        <div class="dashboard-grid">
            <!-- Carte État du système -->
            <div class="card">
                <div class="card-header">
                    <h2>État du système</h2>
                </div>
                <div class="card-body">
                    <div class="stat-group">
                        <div class="stat">
                            <span class="stat-label">CPU</span>
                            <span class="stat-value"><?= $systemInfo['cpu_load']['1min'] ?></span>
                        </div>
                        <div class="stat">
                            <span class="stat-label">RAM</span>
                            <span class="stat-value"><?= $systemInfo['memory']['percent'] ?>%</span>
                        </div>
                        <?php if (isset($systemInfo['temperature'])): ?>
                        <div class="stat">
                            <span class="stat-label">Temp.</span>
                            <span class="stat-value"><?= $systemInfo['temperature'] ?>°C</span>
                        </div>
                        <?php endif; ?>
                    </div>
                    
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: <?= $systemInfo['memory']['percent'] ?>%"></div>
                    </div>
                    <p class="text-muted">
                        <?= formatFileSize($systemInfo['memory']['used']) ?> / 
                        <?= formatFileSize($systemInfo['memory']['total']) ?> utilisés
                    </p>
                </div>
            </div>
            
            <!-- Carte Stockage -->
            <div class="card">
                <div class="card-header">
                    <h2>Stockage vidéos</h2>
                </div>
                <div class="card-body">
                    <div class="storage-chart">
                        <div class="storage-used" style="width: <?= $diskSpace['percent'] ?>%"></div>
                    </div>
                    <div class="storage-info">
                        <p><strong><?= $diskSpace['formatted']['used'] ?></strong> utilisés</p>
                        <p><?= $diskSpace['formatted']['free'] ?> disponibles</p>
                        <p class="text-muted">Total: <?= $diskSpace['formatted']['total'] ?></p>
                    </div>
                </div>
            </div>
            
            <!-- Carte Vidéos -->
            <div class="card">
                <div class="card-header">
                    <h2>Bibliothèque vidéos</h2>
                    <a href="videos.php" class="btn btn-sm">Gérer</a>
                </div>
                <div class="card-body">
                    <div class="video-stats">
                        <div class="big-number"><?= $videoCount ?></div>
                        <p>vidéo<?= $videoCount > 1 ? 's' : '' ?> dans la playlist</p>
                    </div>
                    <?php if ($videoCount > 0): ?>
                    <div class="recent-videos">
                        <h3>Récemment ajoutées</h3>
                        <ul>
                            <?php foreach (array_slice($videos, 0, 3) as $video): ?>
                            <li>
                                <span class="video-name"><?= htmlspecialchars($video['name']) ?></span>
                                <span class="video-size"><?= formatFileSize($video['size']) ?></span>
                            </li>
                            <?php endforeach; ?>
                        </ul>
                    </div>
                    <?php else: ?>
                    <p class="empty-state">Aucune vidéo dans la bibliothèque</p>
                    <?php endif; ?>
                </div>
            </div>
            
            <!-- Carte Contrôles -->
            <div class="card">
                <div class="card-header">
                    <h2>Contrôles rapides</h2>
                </div>
                <div class="card-body">
                    <div class="control-buttons">
                        <button class="btn btn-control" data-action="restart" data-service="vlc">
                            🔄 Redémarrer VLC
                        </button>
                        <button class="btn btn-control" data-action="stop" data-service="vlc">
                            ⏹️ Arrêter VLC
                        </button>
                        <button class="btn btn-control" data-action="start" data-service="vlc">
                            ▶️ Démarrer VLC
                        </button>
                    </div>
                    
                    <div class="quick-links">
                        <h3>Accès rapides</h3>
                        <a href="videos.php" class="quick-link">📹 Gestion des vidéos</a>
                        <a href="settings.php" class="quick-link">⚙️ Paramètres</a>
                        <a href="<?= GLANCES_URL ?>" target="_blank" class="quick-link">📊 Monitoring Glances</a>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Token CSRF pour les requêtes AJAX
        const csrfToken = '<?= $csrf_token ?>';
        
        // Gestion des boutons de contrôle
        document.querySelectorAll('.btn-control').forEach(button => {
            button.addEventListener('click', async function() {
                const action = this.dataset.action;
                const service = this.dataset.service;
                
                if (!confirm(`Êtes-vous sûr de vouloir ${action} ${service} ?`)) {
                    return;
                }
                
                this.disabled = true;
                
                try {
                    const response = await fetch('/api/control.php', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            csrf_token: csrfToken,
                            action: action,
                            service: service + '.service'
                        })
                    });
                    
                    const result = await response.json();
                    
                    if (result.success) {
                        alert('Action effectuée avec succès');
                        setTimeout(() => location.reload(), 2000);
                    } else {
                        alert('Erreur: ' + (result.error || 'Action échouée'));
                    }
                } catch (error) {
                    alert('Erreur de communication avec le serveur');
                } finally {
                    this.disabled = false;
                }
            });
        });
        
        // Rafraîchissement automatique toutes les 30 secondes
        setInterval(() => {
            location.reload();
        }, 30000);
    </script>
</body>
</html>