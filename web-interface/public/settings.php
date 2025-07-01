<?php
/**
 * Paramètres Pi Signage
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

// Redémarrage des services
if (isset($_POST['restart_service'])) {
    if (validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $service = $_POST['service'] ?? '';
        if (in_array($service, ['vlc-signage', 'chromium-kiosk', 'glances', 'nginx'])) {
            $result = restartService($service);
            if ($result['success']) {
                $message = "Service $service redémarré avec succès";
                $messageType = 'success';
                logActivity('SERVICE_RESTARTED', $service);
            } else {
                $message = "Erreur : " . $result['message'];
                $messageType = 'error';
            }
        }
    }
}

// Changement du mode d'affichage
if (isset($_POST['change_mode'])) {
    if (validateCSRFToken($_POST['csrf_token'] ?? '')) {
        $newMode = $_POST['display_mode'] ?? '';
        if (in_array($newMode, ['vlc', 'chromium'])) {
            // Cette fonctionnalité nécessiterait une modification du fichier de config
            $message = "Changement de mode nécessite une réinstallation";
            $messageType = 'warning';
        }
    }
}

// Obtenir les informations système
$systemInfo = getSystemInfo();
$services = [
    'nginx' => checkServiceStatus('nginx'),
    'php-fpm' => checkServiceStatus('php8.2-fpm'),
    'glances' => checkServiceStatus('glances')
];

// Déterminer le service de lecture actuel
$displayMode = DISPLAY_MODE ?? 'vlc';
if ($displayMode === 'chromium') {
    $services['chromium-kiosk'] = checkServiceStatus('chromium-kiosk');
} else {
    $services['vlc-signage'] = checkServiceStatus('vlc-signage');
}

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Paramètres - Pi Signage</title>
    <?php include dirname(__DIR__) . '/templates/header-meta.php'; ?>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
    <?php include dirname(__DIR__) . '/templates/navigation.php'; ?>
    
    <main class="container">
        <h1>⚙️ Paramètres</h1>
        
        <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?>"><?= htmlspecialchars($message) ?></div>
        <?php endif; ?>
        
        <div class="row">
            <div class="col-6">
                <div class="card">
                    <h2>Informations Système</h2>
                    <table class="table">
                        <tr>
                            <td><strong>Hostname</strong></td>
                            <td><?= htmlspecialchars($systemInfo['hostname'] ?? 'N/A') ?></td>
                        </tr>
                        <tr>
                            <td><strong>Modèle Pi</strong></td>
                            <td><?= htmlspecialchars($systemInfo['model'] ?? 'N/A') ?></td>
                        </tr>
                        <tr>
                            <td><strong>Uptime</strong></td>
                            <td><?= htmlspecialchars($systemInfo['uptime'] ?? 'N/A') ?></td>
                        </tr>
                        <tr>
                            <td><strong>Charge système</strong></td>
                            <td><?= htmlspecialchars($systemInfo['load'] ?? 'N/A') ?></td>
                        </tr>
                        <tr>
                            <td><strong>Mode d'affichage</strong></td>
                            <td><?= $displayMode === 'chromium' ? 'Chromium Kiosk' : 'VLC Classic' ?></td>
                        </tr>
                    </table>
                </div>
            </div>
            
            <div class="col-6">
                <div class="card">
                    <h2>État des Services</h2>
                    <table class="table">
                        <?php foreach ($services as $name => $status): ?>
                            <tr>
                                <td><strong><?= ucfirst($name) ?></strong></td>
                                <td>
                                    <span class="status <?= $status ? 'status-active' : 'status-inactive' ?>">
                                        <?= $status ? 'Actif' : 'Inactif' ?>
                                    </span>
                                </td>
                                <td>
                                    <form method="post" style="display: inline;">
                                        <input type="hidden" name="csrf_token" value="<?= generateCSRFToken() ?>">
                                        <input type="hidden" name="service" value="<?= $name ?>">
                                        <button type="submit" name="restart_service" 
                                                class="btn btn-warning btn-sm">
                                            🔄 Redémarrer
                                        </button>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </table>
                </div>
            </div>
        </div>
        
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <h2>Actions Système</h2>
                    
                    <div class="row">
                        <div class="col-4">
                            <h3>Redémarrage Système</h3>
                            <p>Redémarre complètement le Raspberry Pi</p>
                            <button onclick="if(confirm('Êtes-vous sûr de vouloir redémarrer le système ?')) { 
                                        piSignage.controlService('system', 'reboot'); 
                                    }" 
                                    class="btn btn-danger">
                                🔄 Redémarrer le Pi
                            </button>
                        </div>
                        
                        <div class="col-4">
                            <h3>Mise à jour Playlist</h3>
                            <p>Force la mise à jour de la playlist vidéo</p>
                            <button onclick="piSignage.controlPlayer('update-playlist')" 
                                    class="btn btn-success">
                                📋 Mettre à jour
                            </button>
                        </div>
                        
                        <div class="col-4">
                            <h3>Logs Système</h3>
                            <p>Télécharger les logs pour diagnostic</p>
                            <a href="/api/logs.php?download=1" class="btn btn-info">
                                📄 Télécharger les logs
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="row">
            <div class="col-12">
                <div class="card">
                    <h2>Configuration Avancée</h2>
                    
                    <h3>Mode d'Affichage</h3>
                    <p>Mode actuel : <strong><?= $displayMode === 'chromium' ? 'Chromium Kiosk' : 'VLC Classic' ?></strong></p>
                    <p class="text-muted">
                        Pour changer de mode d'affichage, une réinstallation est nécessaire.
                        Exécutez le script d'installation et choisissez le nouveau mode.
                    </p>
                    
                    <h3>Accès aux Interfaces</h3>
                    <ul>
                        <li>
                            <strong>Interface Web :</strong> 
                            <a href="http://<?= $_SERVER['HTTP_HOST'] ?>/" target="_blank">
                                http://<?= $_SERVER['HTTP_HOST'] ?>/
                            </a>
                        </li>
                        <li>
                            <strong>Monitoring Glances :</strong> 
                            <a href="http://<?= $_SERVER['HTTP_HOST'] ?>:61208" target="_blank">
                                http://<?= $_SERVER['HTTP_HOST'] ?>:61208
                            </a>
                        </li>
                        <?php if ($displayMode === 'chromium'): ?>
                        <li>
                            <strong>Player HTML5 :</strong> 
                            <a href="http://<?= $_SERVER['HTTP_HOST'] ?>:8888/player.html" target="_blank">
                                http://<?= $_SERVER['HTTP_HOST'] ?>:8888/player.html
                            </a>
                        </li>
                        <?php endif; ?>
                    </ul>
                    
                    <h3>Scripts de Maintenance</h3>
                    <p>Scripts disponibles sur le système :</p>
                    <ul>
                        <li><code>/opt/scripts/pi-signage-control.sh</code> - Contrôle global</li>
                        <li><code>/opt/scripts/pi-signage-diag</code> - Diagnostic système</li>
                        <li><code>/opt/scripts/update-ytdlp.sh</code> - Mise à jour yt-dlp</li>
                        <li><code>/opt/scripts/glances-password.sh</code> - Changer mot de passe Glances</li>
                    </ul>
                </div>
            </div>
        </div>
    </main>
    
    <script src="assets/js/main.js"></script>
</body>
</html>