<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Chemins des fichiers
$configFile = '/opt/pisignage/config/pisignage.conf';
$logsDir = '/opt/pisignage/logs/';
$backupDir = '/opt/pisignage/backups/';

// Créer le dossier de backup s'il n'existe pas
if (!file_exists($backupDir)) {
    mkdir($backupDir, 0755, true);
}

$action = $_GET['action'] ?? $_POST['action'] ?? '';

switch($action) {
    
    case 'backup':
        // Créer une sauvegarde complète
        $timestamp = date('Y-m-d_H-i-s');
        $backupName = "pisignage_backup_{$timestamp}.tar.gz";
        $backupPath = $backupDir . $backupName;
        
        // Commande pour créer l'archive
        $cmd = sprintf(
            'tar -czf %s -C /opt/pisignage config media scripts web/api web/*.php 2>&1',
            escapeshellarg($backupPath)
        );
        
        $output = shell_exec($cmd);
        
        if (file_exists($backupPath)) {
            echo json_encode([
                'success' => true,
                'message' => 'Backup créé avec succès',
                'filename' => $backupName,
                'size' => filesize($backupPath),
                'path' => $backupPath
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Échec de création du backup',
                'details' => $output
            ]);
        }
        break;
        
    case 'restore':
        // Restaurer depuis un backup
        $backupFile = basename($_POST['backup'] ?? '');
        
        if (!$backupFile || !preg_match('/^pisignage_backup_[\d-_]+\.tar\.gz$/', $backupFile)) {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier de backup invalide'
            ]);
            break;
        }
        
        $backupPath = $backupDir . $backupFile;
        
        if (!file_exists($backupPath)) {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier de backup introuvable'
            ]);
            break;
        }
        
        // Extraire le backup
        $cmd = sprintf(
            'tar -xzf %s -C /opt/pisignage 2>&1',
            escapeshellarg($backupPath)
        );
        
        $output = shell_exec($cmd);
        
        echo json_encode([
            'success' => true,
            'message' => 'Backup restauré avec succès',
            'details' => $output
        ]);
        break;
        
    case 'list-backups':
        // Lister les backups disponibles
        $backups = [];
        if (is_dir($backupDir)) {
            $files = glob($backupDir . 'pisignage_backup_*.tar.gz');
            foreach ($files as $file) {
                $backups[] = [
                    'name' => basename($file),
                    'size' => filesize($file),
                    'date' => date('Y-m-d H:i:s', filemtime($file))
                ];
            }
        }
        
        // Trier par date (plus récent en premier)
        usort($backups, function($a, $b) {
            return strtotime($b['date']) - strtotime($a['date']);
        });
        
        echo json_encode([
            'success' => true,
            'backups' => $backups
        ]);
        break;
        
    case 'view-logs':
        // Voir les logs
        $logType = $_GET['type'] ?? 'pisignage';
        $lines = intval($_GET['lines'] ?? 100);
        $lines = min(max($lines, 10), 1000); // Limiter entre 10 et 1000 lignes
        
        $logFiles = [
            'pisignage' => $logsDir . 'pisignage.log',
            'vlc' => $logsDir . 'vlc.log',
            'nginx' => '/var/log/nginx/error.log',
            'php' => '/var/log/php8.2-fpm.log'
        ];
        
        $logFile = $logFiles[$logType] ?? $logFiles['pisignage'];
        
        if (file_exists($logFile)) {
            // Utiliser tail pour obtenir les dernières lignes
            $cmd = sprintf('tail -n %d %s 2>&1', $lines, escapeshellarg($logFile));
            $content = shell_exec($cmd);
            
            echo json_encode([
                'success' => true,
                'type' => $logType,
                'content' => $content,
                'lines' => $lines,
                'file' => $logFile
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Fichier de log introuvable',
                'file' => $logFile
            ]);
        }
        break;
        
    case 'clear-logs':
        // Nettoyer les logs
        $logType = $_POST['type'] ?? 'all';
        
        $logFiles = [
            'pisignage' => $logsDir . 'pisignage.log',
            'vlc' => $logsDir . 'vlc.log'
        ];
        
        if ($logType === 'all') {
            foreach ($logFiles as $file) {
                if (file_exists($file)) {
                    file_put_contents($file, '');
                }
            }
            $message = 'Tous les logs ont été nettoyés';
        } else {
            $file = $logFiles[$logType] ?? null;
            if ($file && file_exists($file)) {
                file_put_contents($file, '');
                $message = "Log $logType nettoyé";
            } else {
                echo json_encode([
                    'success' => false,
                    'error' => 'Type de log invalide'
                ]);
                break;
            }
        }
        
        echo json_encode([
            'success' => true,
            'message' => $message
        ]);
        break;
        
    case 'save-settings':
        // Sauvegarder les paramètres système
        $settings = $_POST['settings'] ?? [];
        
        // Valider les paramètres
        $allowedSettings = [
            'display_resolution',
            'display_orientation',
            'display_volume',
            'network_ssid',
            'network_password',
            'system_timezone',
            'system_language',
            'auto_start',
            'debug_mode'
        ];
        
        $config = [];
        foreach ($settings as $key => $value) {
            if (in_array($key, $allowedSettings)) {
                // Nettoyer la valeur
                $value = trim($value);
                // Échapper les caractères spéciaux pour le fichier config
                $value = addslashes($value);
                $config[$key] = $value;
            }
        }
        
        // Écrire dans le fichier de configuration
        $configContent = "# PiSignage Configuration\n";
        $configContent .= "# Generated: " . date('Y-m-d H:i:s') . "\n\n";
        
        foreach ($config as $key => $value) {
            $configContent .= "$key=\"$value\"\n";
        }
        
        if (file_put_contents($configFile, $configContent)) {
            // Appliquer certains paramètres immédiatement
            if (isset($config['display_volume'])) {
                $volume = intval($config['display_volume']);
                shell_exec("amixer set Master {$volume}% 2>&1");
            }
            
            echo json_encode([
                'success' => true,
                'message' => 'Paramètres sauvegardés',
                'settings' => $config
            ]);
        } else {
            echo json_encode([
                'success' => false,
                'error' => 'Impossible de sauvegarder les paramètres'
            ]);
        }
        break;
        
    case 'get-settings':
        // Récupérer les paramètres actuels
        $settings = [];
        
        if (file_exists($configFile)) {
            $lines = file($configFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (strpos($line, '#') === 0) continue; // Ignorer les commentaires
                
                if (preg_match('/^([^=]+)="?([^"]*)"?$/', $line, $matches)) {
                    $settings[$matches[1]] = stripslashes($matches[2]);
                }
            }
        }
        
        // Ajouter des valeurs par défaut si manquantes
        $defaults = [
            'display_resolution' => '1920x1080',
            'display_orientation' => 'landscape',
            'display_volume' => '80',
            'system_timezone' => 'Europe/Paris',
            'system_language' => 'fr',
            'auto_start' => 'true',
            'debug_mode' => 'false'
        ];
        
        foreach ($defaults as $key => $value) {
            if (!isset($settings[$key])) {
                $settings[$key] = $value;
            }
        }
        
        echo json_encode([
            'success' => true,
            'settings' => $settings
        ]);
        break;
        
    case 'scan-wifi':
        // Scanner les réseaux WiFi disponibles
        $cmd = 'sudo iwlist wlan0 scan 2>/dev/null | grep -E "ESSID:|Quality" | paste -d " " - - | sed \'s/.*ESSID:"\(.*\)".*/\1/\' 2>&1';
        $output = shell_exec($cmd);
        
        $networks = [];
        if ($output) {
            $lines = explode("\n", trim($output));
            foreach ($lines as $line) {
                if (!empty($line)) {
                    // Extraire le nom et la qualité du signal
                    if (preg_match('/Quality=(\d+)\/\d+.*ESSID:"([^"]*)"/', $line, $matches)) {
                        $networks[] = [
                            'ssid' => $matches[2],
                            'quality' => intval($matches[1]),
                            'signal' => round(($matches[1] / 70) * 100) // Convertir en pourcentage
                        ];
                    } elseif (!empty(trim($line))) {
                        // Si le parsing échoue, ajouter juste le nom
                        $networks[] = [
                            'ssid' => trim($line),
                            'quality' => 0,
                            'signal' => 0
                        ];
                    }
                }
            }
        }
        
        // Trier par signal décroissant
        usort($networks, function($a, $b) {
            return $b['signal'] - $a['signal'];
        });
        
        echo json_encode([
            'success' => true,
            'networks' => $networks
        ]);
        break;
        
    case 'reset-network':
        // Réinitialiser les paramètres réseau
        $commands = [
            'sudo systemctl restart networking',
            'sudo systemctl restart NetworkManager 2>/dev/null || true'
        ];
        
        $output = '';
        foreach ($commands as $cmd) {
            $output .= shell_exec($cmd . ' 2>&1') . "\n";
        }
        
        echo json_encode([
            'success' => true,
            'message' => 'Réseau réinitialisé',
            'details' => $output
        ]);
        break;
        
    default:
        echo json_encode([
            'success' => false,
            'error' => 'Action non reconnue'
        ]);
}