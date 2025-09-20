<?php
/**
 * PiSignage Desktop v3.0 - Dashboard principal
 */

define('PISIGNAGE_DESKTOP', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

// Vérifier l'authentification
requireAuth();
setSecurityHeaders();

// Obtenir les données système
$systemInfo = getSystemInfo();
$serviceStatus = checkServiceStatus(PISIGNAGE_SERVICE);
$videos = listVideos();
$playlist = loadPlaylist();

// Préparer les tokens CSRF
startSecureSession();
$csrf_token = generateCSRFToken();

// Traiter les actions POST
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    if (!verifyCSRFToken($_POST['csrf_token'] ?? '')) {
        $error = 'Token CSRF invalide';
    } else {
        switch ($_POST['action']) {
            case 'control_service':
                $service_action = $_POST['service_action'] ?? '';
                $result = controlService(PISIGNAGE_SERVICE, $service_action);
                if ($result['success']) {
                    $success = "Service {$service_action} avec succès";
                } else {
                    $error = $result['message'];
                }
                break;
                
            case 'control_player':
                $player_action = $_POST['player_action'] ?? '';
                $result = controlPlayer($player_action);
                if ($result['success']) {
                    $success = "Player: {$player_action}";
                } else {
                    $error = $result['message'];
                }
                break;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= APP_NAME ?> - Dashboard</title>
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
                    <span class="status-indicator <?= $serviceStatus['active'] ? 'status-active' : 'status-inactive' ?>">
                        <?= $serviceStatus['active'] ? 'Service actif' : 'Service inactif' ?>
                    </span>
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
                    <a href="index.php" class="nav-link active">
                        📊 Dashboard
                    </a>
                </li>
                <li class="nav-item">
                    <a href="videos.php" class="nav-link">
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

        <!-- Stats Grid -->
        <div class="grid grid-4" style="margin-bottom: 2rem;">
            <!-- CPU -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">🖥️ CPU</h3>
                </div>
                <div class="card-body">
                    <div class="stat">
                        <div class="stat-value"><?= $systemInfo['cpu_percent'] ?? 0 ?>%</div>
                        <div class="stat-label">Utilisation</div>
                    </div>
                    <div style="margin-top: 1rem;">
                        <div class="progress">
                            <div class="progress-bar" style="width: <?= $systemInfo['cpu_percent'] ?? 0 ?>%"></div>
                        </div>
                    </div>
                    <div style="margin-top: 0.5rem; font-size: 0.75rem; color: var(--text-muted);">
                        Load: <?= implode(' ', array_map(fn($l) => number_format($l, 2), $systemInfo['cpu_load'] ?? [0, 0, 0])) ?>
                    </div>
                </div>
            </div>

            <!-- Memory -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">💾 Mémoire</h3>
                </div>
                <div class="card-body">
                    <div class="stat">
                        <div class="stat-value"><?= $systemInfo['memory']['percent'] ?? 0 ?>%</div>
                        <div class="stat-label">Utilisée</div>
                    </div>
                    <div style="margin-top: 1rem;">
                        <div class="progress">
                            <div class="progress-bar" style="width: <?= $systemInfo['memory']['percent'] ?? 0 ?>%"></div>
                        </div>
                    </div>
                    <div style="margin-top: 0.5rem; font-size: 0.75rem; color: var(--text-muted);">
                        <?= formatBytes($systemInfo['memory']['used'] ?? 0) ?> / <?= formatBytes($systemInfo['memory']['total'] ?? 0) ?>
                    </div>
                </div>
            </div>

            <!-- Disk -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">💽 Stockage</h3>
                </div>
                <div class="card-body">
                    <div class="stat">
                        <div class="stat-value"><?= $systemInfo['disk']['percent'] ?? 0 ?>%</div>
                        <div class="stat-label">Utilisé</div>
                    </div>
                    <div style="margin-top: 1rem;">
                        <div class="progress">
                            <div class="progress-bar" style="width: <?= $systemInfo['disk']['percent'] ?? 0 ?>%"></div>
                        </div>
                    </div>
                    <div style="margin-top: 0.5rem; font-size: 0.75rem; color: var(--text-muted);">
                        <?= formatBytes($systemInfo['disk']['free'] ?? 0) ?> libre
                    </div>
                </div>
            </div>

            <!-- Temperature -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">🌡️ Température</h3>
                </div>
                <div class="card-body">
                    <div class="stat">
                        <div class="stat-value"><?= $systemInfo['temperature'] ?? '--' ?></div>
                        <div class="stat-label">°C</div>
                    </div>
                    <div style="margin-top: 1rem;">
                        <?php $temp = $systemInfo['temperature'] ?? 0; ?>
                        <div class="progress">
                            <div class="progress-bar" style="width: <?= min(100, max(0, ($temp - 30) * 2)) ?>%; background-color: <?= $temp > 70 ? 'var(--error)' : ($temp > 60 ? 'var(--warning)' : 'var(--success)') ?>"></div>
                        </div>
                    </div>
                    <div style="margin-top: 0.5rem; font-size: 0.75rem; color: var(--text-muted);">
                        <?= $temp > 70 ? 'Chaud' : ($temp > 60 ? 'Tiède' : 'Normal') ?>
                    </div>
                </div>
            </div>
        </div>

        <!-- Controls Grid -->
        <div class="grid grid-2" style="margin-bottom: 2rem;">
            <!-- Service Control -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">🎮 Contrôle Service</h3>
                </div>
                <div class="card-body">
                    <div style="margin-bottom: 1rem;">
                        <strong>Statut:</strong> 
                        <span class="status-indicator <?= $serviceStatus['active'] ? 'status-active' : 'status-inactive' ?>">
                            <?= ucfirst($serviceStatus['status']) ?>
                        </span>
                    </div>
                    <form method="post" style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                        <input type="hidden" name="action" value="control_service">
                        <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                        
                        <button type="submit" name="service_action" value="start" class="btn btn-success btn-sm">
                            ▶️ Start
                        </button>
                        <button type="submit" name="service_action" value="stop" class="btn btn-danger btn-sm">
                            ⏹️ Stop
                        </button>
                        <button type="submit" name="service_action" value="restart" class="btn btn-warning btn-sm">
                            🔄 Restart
                        </button>
                    </form>
                </div>
            </div>

            <!-- Player Control -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">📺 Contrôle Player</h3>
                </div>
                <div class="card-body">
                    <div style="margin-bottom: 1rem;">
                        <strong>Playlist:</strong> <?= count($playlist) ?> vidéos
                    </div>
                    <form method="post" style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
                        <input type="hidden" name="action" value="control_player">
                        <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
                        
                        <button type="submit" name="player_action" value="play" class="btn btn-success btn-sm">
                            ▶️ Play
                        </button>
                        <button type="submit" name="player_action" value="pause" class="btn btn-warning btn-sm">
                            ⏸️ Pause
                        </button>
                        <button type="submit" name="player_action" value="next" class="btn btn-primary btn-sm">
                            ⏭️ Next
                        </button>
                        <button type="submit" name="player_action" value="reload" class="btn btn-secondary btn-sm">
                            🔄 Reload
                        </button>
                    </form>
                </div>
            </div>
        </div>

        <!-- Info Grid -->
        <div class="grid grid-2">
            <!-- Videos Info -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">🎬 Vidéos</h3>
                    <a href="videos.php" class="btn btn-primary btn-sm">Gérer</a>
                </div>
                <div class="card-body">
                    <div class="stat">
                        <div class="stat-value"><?= count($videos) ?></div>
                        <div class="stat-label">Fichiers</div>
                    </div>
                    <?php if (!empty($videos)): ?>
                        <div style="margin-top: 1rem;">
                            <div style="font-size: 0.875rem; color: var(--text-secondary);">
                                Dernière: <?= htmlspecialchars(reset($videos)['name']) ?>
                            </div>
                            <div style="font-size: 0.75rem; color: var(--text-muted);">
                                <?= date('d/m/Y H:i', reset($videos)['modified']) ?>
                            </div>
                        </div>
                    <?php endif; ?>
                </div>
            </div>

            <!-- System Info -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">ℹ️ Système</h3>
                </div>
                <div class="card-body">
                    <div style="font-size: 0.875rem; line-height: 1.6;">
                        <div><strong>Version:</strong> <?= APP_VERSION ?></div>
                        <div><strong>Mode:</strong> <?= ucfirst(DISPLAY_MODE) ?></div>
                        <div><strong>Uptime:</strong> <span id="uptime">--</span></div>
                        <div><strong>IP:</strong> <span id="ip-address">--</span></div>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <script src="assets/js/app.js"></script>
    <script>
        // Auto-refresh des données toutes les 30 secondes
        let refreshInterval;
        
        function startAutoRefresh() {
            refreshInterval = setInterval(() => {
                location.reload();
            }, 30000);
        }
        
        function stopAutoRefresh() {
            if (refreshInterval) {
                clearInterval(refreshInterval);
            }
        }
        
        // Obtenir l'uptime et l'IP
        async function updateSystemInfo() {
            try {
                const response = await fetch('/api/v1/endpoints.php?action=system_info');
                const data = await response.json();
                
                if (data.success) {
                    document.getElementById('uptime').textContent = data.data.uptime || '--';
                    document.getElementById('ip-address').textContent = data.data.ip || '--';
                }
            } catch (error) {
                console.error('Erreur lors de la récupération des infos système:', error);
            }
        }
        
        // Initialisation
        document.addEventListener('DOMContentLoaded', function() {
            updateSystemInfo();
            startAutoRefresh();
            
            // Arrêter le refresh si la page n'est pas visible
            document.addEventListener('visibilitychange', function() {
                if (document.hidden) {
                    stopAutoRefresh();
                } else {
                    startAutoRefresh();
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