<?php
/**
 * Pi Signage Digital - Paramètres
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

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Vérifier le token CSRF
    checkCSRF($_POST['csrf_token'] ?? '');
    
    $action = $_POST['action'] ?? '';
    
    switch ($action) {
        case 'change_password':
            $current_password = $_POST['current_password'] ?? '';
            $new_password = $_POST['new_password'] ?? '';
            $confirm_password = $_POST['confirm_password'] ?? '';
            
            // Charger la config actuelle
            $systemConfig = loadSystemConfig();
            
            // Vérifier le mot de passe actuel
            if (!password_verify($current_password, password_hash($systemConfig['WEB_ADMIN_PASSWORD'], PASSWORD_DEFAULT))) {
                $message = 'Mot de passe actuel incorrect';
                $messageType = 'error';
            } elseif (strlen($new_password) < 6) {
                $message = 'Le nouveau mot de passe doit contenir au moins 6 caractères';
                $messageType = 'error';
            } elseif ($new_password !== $confirm_password) {
                $message = 'Les mots de passe ne correspondent pas';
                $messageType = 'error';
            } else {
                // Mettre à jour le mot de passe
                $configFile = CONFIG_FILE;
                $configContent = file_get_contents($configFile);
                $configContent = preg_replace(
                    '/^WEB_ADMIN_PASSWORD=".*"$/m',
                    'WEB_ADMIN_PASSWORD="' . $new_password . '"',
                    $configContent
                );
                
                if (file_put_contents($configFile, $configContent)) {
                    $message = 'Mot de passe modifié avec succès';
                    $messageType = 'success';
                    logAction('Password changed');
                } else {
                    $message = 'Erreur lors de la modification du mot de passe';
                    $messageType = 'error';
                }
            }
            break;
            
        case 'update_sync':
            $sync_interval = intval($_POST['sync_interval'] ?? 6);
            $gdrive_folder = $_POST['gdrive_folder'] ?? 'Signage';
            
            // Mettre à jour la configuration
            $configFile = CONFIG_FILE;
            $configContent = file_get_contents($configFile);
            $configContent = preg_replace(
                '/^GDRIVE_FOLDER=".*"$/m',
                'GDRIVE_FOLDER="' . $gdrive_folder . '"',
                $configContent
            );
            
            if (file_put_contents($configFile, $configContent)) {
                // Mettre à jour le cron pour l'intervalle de sync
                $cronFile = '/etc/cron.d/pi-signage-sync';
                if (file_exists($cronFile)) {
                    $hours = [];
                    for ($i = 0; $i < 24; $i += $sync_interval) {
                        $hours[] = $i;
                    }
                    $hoursStr = implode(',', $hours);
                    
                    $cronContent = "# Synchronisation automatique des vidéos\n";
                    $cronContent .= "0 $hoursStr * * * root /opt/scripts/sync-videos.sh >> /var/log/pi-signage/sync-cron.log 2>&1\n";
                    
                    file_put_contents($cronFile, $cronContent);
                }
                
                $message = 'Paramètres de synchronisation mis à jour';
                $messageType = 'success';
                logAction('Sync settings updated');
            } else {
                $message = 'Erreur lors de la mise à jour';
                $messageType = 'error';
            }
            break;
            
        case 'clear_logs':
            $logsCleared = 0;
            $logDir = LOG_DIR;
            
            if (is_dir($logDir)) {
                $files = glob($logDir . '/*.log');
                foreach ($files as $file) {
                    if (file_put_contents($file, '') !== false) {
                        $logsCleared++;
                    }
                }
            }
            
            $message = "$logsCleared fichier(s) de log vidé(s)";
            $messageType = 'success';
            logAction('Logs cleared');
            break;
            
        case 'system_update':
            // Mise à jour yt-dlp
            $output = shell_exec('sudo yt-dlp -U 2>&1');
            $message = 'Mise à jour effectuée : ' . ($output ?: 'Déjà à jour');
            $messageType = 'success';
            logAction('System update');
            break;
    }
}

// Charger la configuration actuelle
$systemConfig = loadSystemConfig();
$csrfToken = generateCSRF();

// Récupérer l'intervalle de synchronisation actuel
$currentSyncInterval = 6; // Par défaut 6h
$cronFile = '/etc/cron.d/pi-signage-sync';
if (file_exists($cronFile)) {
    $cronContent = file_get_contents($cronFile);
    if (preg_match('/^0 ([\d,]+) \* \* \*/m', $cronContent, $matches)) {
        $hours = explode(',', $matches[1]);
        if (count($hours) > 1) {
            $currentSyncInterval = $hours[1] - $hours[0];
        }
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pi Signage - Paramètres</title>
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
                <li class="active">
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
                <h1>Paramètres</h1>
            </header>
            
            <?php if ($message): ?>
            <div class="alert alert-<?= $messageType ?> alert-dismissible">
                <?= htmlspecialchars($message) ?>
                <button type="button" class="close" data-dismiss="alert">&times;</button>
            </div>
            <?php endif; ?>
            
            <!-- Changement de mot de passe -->
            <div class="card">
                <div class="card-header">
                    <h2>Sécurité</h2>
                </div>
                <div class="card-body">
                    <form method="POST">
                        <input type="hidden" name="csrf_token" value="<?= $csrfToken ?>">
                        <input type="hidden" name="action" value="change_password">
                        
                        <div class="form-group">
                            <label for="current_password">Mot de passe actuel</label>
                            <input type="password" 
                                   id="current_password" 
                                   name="current_password" 
                                   class="form-control" 
                                   required>
                        </div>
                        
                        <div class="form-group">
                            <label for="new_password">Nouveau mot de passe</label>
                            <input type="password" 
                                   id="new_password" 
                                   name="new_password" 
                                   class="form-control" 
                                   minlength="6"
                                   required>
                            <small class="form-text text-muted">
                                Minimum 6 caractères
                            </small>
                        </div>
                        
                        <div class="form-group">
                            <label for="confirm_password">Confirmer le mot de passe</label>
                            <input type="password" 
                                   id="confirm_password" 
                                   name="confirm_password" 
                                   class="form-control" 
                                   minlength="6"
                                   required>
                        </div>
                        
                        <button type="submit" class="btn btn-primary">
                            Changer le mot de passe
                        </button>
                    </form>
                </div>
            </div>
            
            <!-- Paramètres de synchronisation -->
            <div class="card">
                <div class="card-header">
                    <h2>Synchronisation Google Drive</h2>
                </div>
                <div class="card-body">
                    <form method="POST">
                        <input type="hidden" name="csrf_token" value="<?= $csrfToken ?>">
                        <input type="hidden" name="action" value="update_sync">
                        
                        <div class="form-group">
                            <label for="gdrive_folder">Dossier Google Drive</label>
                            <input type="text" 
                                   id="gdrive_folder" 
                                   name="gdrive_folder" 
                                   class="form-control" 
                                   value="<?= htmlspecialchars($systemConfig['GDRIVE_FOLDER'] ?? 'Signage') ?>"
                                   required>
                            <small class="form-text text-muted">
                                Nom du dossier contenant vos vidéos dans Google Drive
                            </small>
                        </div>
                        
                        <div class="form-group">
                            <label for="sync_interval">Intervalle de synchronisation</label>
                            <select id="sync_interval" name="sync_interval" class="form-control">
                                <option value="1" <?= $currentSyncInterval == 1 ? 'selected' : '' ?>>Toutes les heures</option>
                                <option value="2" <?= $currentSyncInterval == 2 ? 'selected' : '' ?>>Toutes les 2 heures</option>
                                <option value="4" <?= $currentSyncInterval == 4 ? 'selected' : '' ?>>Toutes les 4 heures</option>
                                <option value="6" <?= $currentSyncInterval == 6 ? 'selected' : '' ?>>Toutes les 6 heures</option>
                                <option value="12" <?= $currentSyncInterval == 12 ? 'selected' : '' ?>>Toutes les 12 heures</option>
                                <option value="24" <?= $currentSyncInterval == 24 ? 'selected' : '' ?>>Une fois par jour</option>
                            </select>
                        </div>
                        
                        <button type="submit" class="btn btn-primary">
                            Mettre à jour
                        </button>
                        
                        <a href="/opt/scripts/setup-gdrive.sh" class="btn btn-secondary" onclick="return confirm('Cela va lancer la configuration Google Drive. Continuer ?')">
                            Reconfigurer Google Drive
                        </a>
                    </form>
                </div>
            </div>
            
            <!-- Maintenance -->
            <div class="card">
                <div class="card-header">
                    <h2>Maintenance</h2>
                </div>
                <div class="card-body">
                    <div class="maintenance-actions">
                        <form method="POST" style="display: inline-block;">
                            <input type="hidden" name="csrf_token" value="<?= $csrfToken ?>">
                            <input type="hidden" name="action" value="clear_logs">
                            <button type="submit" class="btn btn-warning" onclick="return confirm('Vider tous les fichiers de log ?')">
                                <i class="icon-trash"></i> Vider les logs
                            </button>
                        </form>
                        
                        <form method="POST" style="display: inline-block;">
                            <input type="hidden" name="csrf_token" value="<?= $csrfToken ?>">
                            <input type="hidden" name="action" value="system_update">
                            <button type="submit" class="btn btn-info">
                                <i class="icon-refresh"></i> Mettre à jour yt-dlp
                            </button>
                        </form>
                        
                        <a href="/opt/scripts/pi-signage-diag.sh" class="btn btn-secondary" target="_blank">
                            <i class="icon-tools"></i> Diagnostic système
                        </a>
                    </div>
                    
                    <div class="info-box mt-3">
                        <i class="icon-info-circle"></i>
                        <div>
                            <p><strong>Sauvegarde recommandée</strong></p>
                            <p>Pensez à sauvegarder régulièrement votre configuration et vos vidéos.</p>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Informations système -->
            <div class="card">
                <div class="card-header">
                    <h2>Informations système</h2>
                </div>
                <div class="card-body">
                    <div class="system-info">
                        <div class="info-row">
                            <span class="label">Version Pi Signage:</span>
                            <span class="value"><?= VERSION ?></span>
                        </div>
                        <div class="info-row">
                            <span class="label">Version PHP:</span>
                            <span class="value"><?= phpversion() ?></span>
                        </div>
                        <div class="info-row">
                            <span class="label">Serveur web:</span>
                            <span class="value"><?= $_SERVER['SERVER_SOFTWARE'] ?? 'nginx' ?></span>
                        </div>
                        <div class="info-row">
                            <span class="label">Système:</span>
                            <span class="value"><?= php_uname('s') . ' ' . php_uname('r') ?></span>
                        </div>
                        <div class="info-row">
                            <span class="label">Architecture:</span>
                            <span class="value"><?= php_uname('m') ?></span>
                        </div>
                        <div class="info-row">
                            <span class="label">Hostname:</span>
                            <span class="value"><?= gethostname() ?></span>
                        </div>
                    </div>
                </div>
            </div>
        </main>
    </div>
    
    <script src="assets/js/main.js"></script>
    <script>
    // Validation du formulaire de mot de passe
    document.getElementById('confirm_password')?.addEventListener('input', function() {
        const newPassword = document.getElementById('new_password').value;
        const confirmPassword = this.value;
        
        if (newPassword !== confirmPassword) {
            this.setCustomValidity('Les mots de passe ne correspondent pas');
        } else {
            this.setCustomValidity('');
        }
    });
    </script>
    
    <style>
    .maintenance-actions {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
    }
    
    .info-box {
        display: flex;
        align-items: start;
        gap: 15px;
        background: rgba(33, 150, 243, 0.1);
        border: 1px solid var(--info-color);
        border-radius: 4px;
        padding: 15px;
    }
    
    .info-box i {
        font-size: 24px;
        color: var(--info-color);
        flex-shrink: 0;
    }
    
    .mt-3 {
        margin-top: 1rem;
    }
    </style>
</body>
</html>