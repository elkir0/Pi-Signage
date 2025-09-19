<?php
// PiSignage Web Interface
// Version: 1.0

session_start();

// Configuration
$config_file = '/opt/pisignage/config/pisignage.conf';
$media_dir = '/opt/pisignage/media';
$log_dir = '/opt/pisignage/logs';

// Fonction pour lire la configuration
function load_config($file) {
    $config = [];
    if (file_exists($file)) {
        $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        $current_section = '';
        
        foreach ($lines as $line) {
            $line = trim($line);
            if (empty($line) || $line[0] == '#') continue;
            
            if (preg_match('/^\[(.+)\]$/', $line, $matches)) {
                $current_section = $matches[1];
            } elseif (preg_match('/^(.+?)\s*=\s*(.+)$/', $line, $matches)) {
                $config[$current_section][trim($matches[1])] = trim($matches[2], '"');
            }
        }
    }
    return $config;
}

$config = load_config($config_file);
$display_name = $config['general']['display_name'] ?? 'PiSignage';

?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($display_name); ?></title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .card {
            background: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            margin: 5px;
            text-decoration: none;
            display: inline-block;
        }
        .btn-primary { background-color: #3498db; color: white; }
        .btn-success { background-color: #2ecc71; color: white; }
        .btn-danger { background-color: #e74c3c; color: white; }
        .btn-warning { background-color: #f39c12; color: white; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .status {
            padding: 10px;
            border-radius: 3px;
            margin: 10px 0;
        }
        .status.online { background-color: #d4edda; color: #155724; }
        .status.offline { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><?php echo htmlspecialchars($display_name); ?></h1>
            <p>Interface de gestion de l'affichage numérique</p>
        </div>

        <div class="grid">
            <div class="card">
                <h2>État du système</h2>
                <div id="system-status" class="status offline">
                    Vérification en cours...
                </div>
                <button class="btn btn-primary" onclick="checkStatus()">Actualiser</button>
            </div>

            <div class="card">
                <h2>Contrôle du lecteur</h2>
                <button class="btn btn-success" onclick="controlPlayer('start')">Démarrer</button>
                <button class="btn btn-warning" onclick="controlPlayer('restart')">Redémarrer</button>
                <button class="btn btn-danger" onclick="controlPlayer('stop')">Arrêter</button>
            </div>

            <div class="card">
                <h2>Gestion des médias</h2>
                <p>Nombre de fichiers: <span id="media-count">-</span></p>
                <button class="btn btn-primary" onclick="window.location.href='media.php'">Gérer les médias</button>
            </div>

            <div class="card">
                <h2>Configuration</h2>
                <p>Mode: <?php echo htmlspecialchars($config['general']['mode'] ?? 'Non défini'); ?></p>
                <p>Résolution: <?php echo htmlspecialchars($config['display']['resolution'] ?? 'Auto'); ?></p>
                <button class="btn btn-primary" onclick="window.location.href='config.php'">Configurer</button>
            </div>

            <div class="card">
                <h2>Logs système</h2>
                <button class="btn btn-primary" onclick="window.location.href='logs.php'">Voir les logs</button>
            </div>
        </div>
    </div>

    <script>
        function checkStatus() {
            fetch('api/control.php?action=status')
                .then(response => response.json())
                .then(data => {
                    const statusDiv = document.getElementById('system-status');
                    if (data.status === 'online') {
                        statusDiv.className = 'status online';
                        statusDiv.textContent = 'Système en ligne';
                    } else {
                        statusDiv.className = 'status offline';
                        statusDiv.textContent = 'Système hors ligne';
                    }
                })
                .catch(error => {
                    const statusDiv = document.getElementById('system-status');
                    statusDiv.className = 'status offline';
                    statusDiv.textContent = 'Erreur de connexion';
                });
        }

        function controlPlayer(action) {
            fetch(`api/control.php?action=player&command=${action}`)
                .then(response => response.json())
                .then(data => {
                    alert(data.message || 'Commande exécutée');
                    checkStatus();
                })
                .catch(error => {
                    alert('Erreur lors de l\'exécution de la commande');
                });
        }

        // Vérification du statut au chargement
        document.addEventListener('DOMContentLoaded', checkStatus);
        
        // Actualisation automatique toutes les 30 secondes
        setInterval(checkStatus, 30000);
    </script>
</body>
</html>