<?php
/**
 * Pi Signage Digital - Visualisation des logs
 * @version 2.0.0
 */

session_start();
require_once 'includes/config.php';
require_once 'includes/functions.php';
require_once 'includes/session.php';

// Vérifier l'authentification
checkAuth();

// Sélection du fichier de log
$logFile = $_GET['file'] ?? 'vlc.log';
$allowedLogs = [
    'vlc.log' => 'VLC',
    'sync.log' => 'Synchronisation',
    'health.log' => 'Santé système',
    'monitoring.log' => 'Monitoring',
    'web-actions.log' => 'Actions web',
    'watchdog.log' => 'Watchdog'
];

// Sécurité : vérifier que le log demandé est autorisé
if (!array_key_exists($logFile, $allowedLogs)) {
    $logFile = 'vlc.log';
}

// Nombre de lignes à afficher
$lines = isset($_GET['lines']) ? intval($_GET['lines']) : 100;
$lines = min(max($lines, 50), 1000); // Entre 50 et 1000

// Récupérer les logs
$logContent = getRecentLogs($logFile, $lines);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage - Logs</title>
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
                <li class="active">
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
                <h1>Logs système</h1>
            </header>
            
            <!-- Sélecteur de logs -->
            <div class="card">
                <div class="card-header">
                    <h2>Sélection du fichier</h2>
                </div>
                <div class="card-body">
                    <form method="GET" class="log-selector">
                        <div class="form-row">
                            <div class="form-group col-md-6">
                                <label for="file">Fichier de log</label>
                                <select name="file" id="file" class="form-control" onchange="this.form.submit()">
                                    <?php foreach ($allowedLogs as $file => $name): ?>
                                    <option value="<?= $file ?>" <?= $file === $logFile ? 'selected' : '' ?>>
                                        <?= $name ?>
                                    </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            
                            <div class="form-group col-md-6">
                                <label for="lines">Nombre de lignes</label>
                                <select name="lines" id="lines" class="form-control" onchange="this.form.submit()">
                                    <option value="50" <?= $lines == 50 ? 'selected' : '' ?>>50 dernières</option>
                                    <option value="100" <?= $lines == 100 ? 'selected' : '' ?>>100 dernières</option>
                                    <option value="250" <?= $lines == 250 ? 'selected' : '' ?>>250 dernières</option>
                                    <option value="500" <?= $lines == 500 ? 'selected' : '' ?>>500 dernières</option>
                                    <option value="1000" <?= $lines == 1000 ? 'selected' : '' ?>>1000 dernières</option>
                                </select>
                            </div>
                        </div>
                        
                        <div class="form-actions">
                            <button type="submit" class="btn btn-primary">
                                <i class="icon-refresh"></i> Actualiser
                            </button>
                            
                            <a href="?file=<?= $logFile ?>&lines=<?= $lines ?>&download=1" class="btn btn-secondary">
                                <i class="icon-download"></i> Télécharger
                            </a>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- Contenu des logs -->
            <div class="card">
                <div class="card-header">
                    <h2><?= $allowedLogs[$logFile] ?></h2>
                    <div class="card-tools">
                        <span class="badge"><?= count($logContent) ?> lignes</span>
                    </div>
                </div>
                <div class="card-body">
                    <?php if (empty($logContent)): ?>
                    <p class="text-muted">Aucune entrée de log trouvée.</p>
                    <?php else: ?>
                    <div class="log-viewer">
                        <pre><?php
                        foreach ($logContent as $line) {
                            // Colorier les niveaux de log
                            $line = htmlspecialchars($line);
                            $line = preg_replace('/\[ERROR\]/', '<span class="log-error">[ERROR]</span>', $line);
                            $line = preg_replace('/\[WARN\]/', '<span class="log-warn">[WARN]</span>', $line);
                            $line = preg_replace('/\[INFO\]/', '<span class="log-info">[INFO]</span>', $line);
                            $line = preg_replace('/\[DEBUG\]/', '<span class="log-debug">[DEBUG]</span>', $line);
                            
                            // Colorier les timestamps
                            $line = preg_replace('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/', '<span class="log-timestamp">$0</span>', $line);
                            
                            echo $line . "\n";
                        }
                        ?></pre>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
            
            <!-- Statistiques des logs -->
            <div class="card">
                <div class="card-header">
                    <h2>Statistiques</h2>
                </div>
                <div class="card-body">
                    <?php
                    // Compter les types d'entrées
                    $stats = [
                        'ERROR' => 0,
                        'WARN' => 0,
                        'INFO' => 0,
                        'DEBUG' => 0
                    ];
                    
                    foreach ($logContent as $line) {
                        foreach ($stats as $level => $count) {
                            if (strpos($line, "[$level]") !== false) {
                                $stats[$level]++;
                            }
                        }
                    }
                    ?>
                    
                    <div class="stats-mini">
                        <div class="stat-mini">
                            <span class="stat-label">Erreurs</span>
                            <span class="stat-value text-danger"><?= $stats['ERROR'] ?></span>
                        </div>
                        <div class="stat-mini">
                            <span class="stat-label">Avertissements</span>
                            <span class="stat-value text-warning"><?= $stats['WARN'] ?></span>
                        </div>
                        <div class="stat-mini">
                            <span class="stat-label">Informations</span>
                            <span class="stat-value text-info"><?= $stats['INFO'] ?></span>
                        </div>
                        <div class="stat-mini">
                            <span class="stat-label">Debug</span>
                            <span class="stat-value text-muted"><?= $stats['DEBUG'] ?></span>
                        </div>
                    </div>
                </div>
            </div>
        </main>
    </div>
    
    <script src="assets/js/main.js"></script>
    <style>
    /* Styles spécifiques pour les logs */
    .log-viewer {
        background: #1a1a1a;
        border-radius: 4px;
        padding: 15px;
        overflow-x: auto;
        max-height: 600px;
        overflow-y: auto;
        font-family: 'Consolas', 'Monaco', monospace;
        font-size: 13px;
        line-height: 1.5;
    }
    
    .log-viewer pre {
        margin: 0;
        color: #e0e0e0;
    }
    
    .log-error { color: #f44336; font-weight: bold; }
    .log-warn { color: #ff9800; }
    .log-info { color: #2196F3; }
    .log-debug { color: #9e9e9e; }
    .log-timestamp { color: #4CAF50; }
    
    .form-row {
        display: flex;
        gap: 20px;
        margin-bottom: 20px;
    }
    
    .form-row .form-group {
        flex: 1;
    }
    
    .form-actions {
        display: flex;
        gap: 10px;
    }
    
    .stats-mini {
        display: flex;
        justify-content: space-around;
        padding: 20px 0;
    }
    
    .stat-mini {
        text-align: center;
    }
    
    .stat-label {
        display: block;
        color: var(--text-secondary);
        font-size: 14px;
        margin-bottom: 5px;
    }
    
    .stat-value {
        display: block;
        font-size: 24px;
        font-weight: bold;
    }
    </style>
</body>
</html>