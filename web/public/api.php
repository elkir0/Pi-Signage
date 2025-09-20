<?php
/**
 * PiSignage Desktop v3.0 - Documentation API
 */

define('PISIGNAGE_DESKTOP', true);
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_once '../includes/functions.php';

// Vérifier l'authentification
requireAuth();
setSecurityHeaders();

// Obtenir l'IP du serveur
$server_ip = $_SERVER['HTTP_HOST'] ?? $_SERVER['SERVER_NAME'] ?? 'localhost';
$api_base = "http://{$server_ip}/api/v1/endpoints.php";
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= APP_NAME ?> - API Documentation</title>
    <link rel="stylesheet" href="assets/css/style.css">
    <meta name="theme-color" content="#3b82f6">
    <style>
        .endpoint {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: var(--radius);
            padding: 1rem;
            margin-bottom: 1rem;
        }
        
        .method {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .method-get { background: var(--success); color: white; }
        .method-post { background: var(--accent-primary); color: white; }
        .method-delete { background: var(--error); color: white; }
        
        .code-block {
            background: var(--bg-tertiary);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 1rem;
            margin: 0.5rem 0;
            font-family: 'Courier New', monospace;
            font-size: 0.875rem;
            overflow-x: auto;
        }
        
        .test-button {
            margin-top: 0.5rem;
        }
    </style>
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
                    <a href="index.php" class="nav-link">
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
                    <a href="api.php" class="nav-link active">
                        🔧 API
                    </a>
                </li>
            </ul>
        </div>
    </nav>

    <!-- Main Content -->
    <main class="container" style="margin-top: 2rem; margin-bottom: 2rem;">
        
        <!-- Introduction -->
        <div class="card" style="margin-bottom: 2rem;">
            <div class="card-header">
                <h2 class="card-title">🔧 API REST PiSignage Desktop</h2>
            </div>
            <div class="card-body">
                <p>Cette API permet de contrôler PiSignage Desktop depuis des applications externes ou mobiles.</p>
                
                <h3>Base URL</h3>
                <div class="code-block">
                    <?= $api_base ?>
                </div>
                
                <h3>Format de réponse</h3>
                <div class="code-block">
{
  "success": true|false,
  "data": object|array|null,
  "message": "string",
  "timestamp": "ISO 8601"
}
                </div>
                
                <h3>CORS</h3>
                <p>L'API supporte CORS pour les requêtes cross-origin.</p>
            </div>
        </div>

        <!-- Endpoints -->
        <div class="grid">
            
            <!-- System Info -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-get">GET</span>
                    <strong>Informations système</strong>
                </div>
                
                <div class="code-block">
GET <?= $api_base ?>?action=system_info
                </div>
                
                <p>Retourne les informations système (CPU, mémoire, disque, température, uptime, IP).</p>
                
                <button onclick="testEndpoint('system_info', 'GET')" class="btn btn-primary btn-sm test-button">
                    🧪 Tester
                </button>
            </div>
            
            <!-- Service Status -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-get">GET</span>
                    <strong>Statut des services</strong>
                </div>
                
                <div class="code-block">
GET <?= $api_base ?>?action=service_status
                </div>
                
                <p>Retourne le statut des services système (PiSignage, nginx).</p>
                
                <button onclick="testEndpoint('service_status', 'GET')" class="btn btn-primary btn-sm test-button">
                    🧪 Tester
                </button>
            </div>
            
            <!-- Service Control -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-post">POST</span>
                    <strong>Contrôle des services</strong>
                </div>
                
                <div class="code-block">
POST <?= $api_base ?>
Content-Type: application/json

{
  "action": "service_control",
  "service": "pisignage-desktop.service",
  "action": "start|stop|restart"
}
                </div>
                
                <p>Démarre, arrête ou redémarre un service.</p>
            </div>
            
            <!-- Videos -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-get">GET</span>
                    <strong>Liste des vidéos</strong>
                </div>
                
                <div class="code-block">
GET <?= $api_base ?>?action=videos
                </div>
                
                <p>Retourne la liste de toutes les vidéos disponibles.</p>
                
                <button onclick="testEndpoint('videos', 'GET')" class="btn btn-primary btn-sm test-button">
                    🧪 Tester
                </button>
            </div>
            
            <!-- Playlist -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-get">GET</span>
                    <span class="method method-post">POST</span>
                    <strong>Playlist</strong>
                </div>
                
                <div class="code-block">
GET <?= $api_base ?>?action=playlist
POST <?= $api_base ?>
Content-Type: application/json

{
  "action": "playlist",
  "playlist": [
    {
      "file": "video.mp4",
      "duration": 30,
      "enabled": true
    }
  ]
}
                </div>
                
                <p>Récupère ou modifie la playlist actuelle.</p>
                
                <button onclick="testEndpoint('playlist', 'GET')" class="btn btn-primary btn-sm test-button">
                    🧪 Tester (GET)
                </button>
            </div>
            
            <!-- Player Control -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-post">POST</span>
                    <strong>Contrôle du player</strong>
                </div>
                
                <div class="code-block">
POST <?= $api_base ?>
Content-Type: application/json

{
  "action": "player_control",
  "action": "play|pause|stop|next|previous|reload"
}
                </div>
                
                <p>Contrôle la lecture des vidéos.</p>
                
                <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.5rem;">
                    <button onclick="testPlayerControl('play')" class="btn btn-success btn-sm">▶️ Play</button>
                    <button onclick="testPlayerControl('pause')" class="btn btn-warning btn-sm">⏸️ Pause</button>
                    <button onclick="testPlayerControl('next')" class="btn btn-primary btn-sm">⏭️ Next</button>
                </div>
            </div>
            
            <!-- YouTube Download -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-post">POST</span>
                    <strong>Téléchargement YouTube</strong>
                </div>
                
                <div class="code-block">
POST <?= $api_base ?>
Content-Type: application/json

{
  "action": "youtube_download",
  "url": "https://youtube.com/watch?v=..."
}
                </div>
                
                <p>Télécharge une vidéo depuis YouTube.</p>
            </div>
            
            <!-- Stats (Mobile) -->
            <div class="endpoint">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 1rem;">
                    <span class="method method-get">GET</span>
                    <strong>Stats rapides</strong>
                </div>
                
                <div class="code-block">
GET <?= $api_base ?>?action=stats
                </div>
                
                <p>Retourne les statistiques essentielles pour les apps mobiles.</p>
                
                <button onclick="testEndpoint('stats', 'GET')" class="btn btn-primary btn-sm test-button">
                    🧪 Tester
                </button>
            </div>
            
        </div>

        <!-- Test Results -->
        <div id="test-results" class="card hidden" style="margin-top: 2rem;">
            <div class="card-header">
                <h3 class="card-title">🧪 Résultats du test</h3>
                <button onclick="document.getElementById('test-results').classList.add('hidden')" class="btn btn-secondary btn-sm">✕</button>
            </div>
            <div class="card-body">
                <div id="test-output" class="code-block"></div>
            </div>
        </div>

        <!-- Mobile App Example -->
        <div class="card" style="margin-top: 2rem;">
            <div class="card-header">
                <h3 class="card-title">📱 Exemple d'application mobile</h3>
            </div>
            <div class="card-body">
                <p>Voici un exemple simple d'utilisation de l'API depuis une application mobile :</p>
                
                <div class="code-block">
// JavaScript / React Native
async function getSystemStats() {
  try {
    const response = await fetch('<?= $api_base ?>?action=stats');
    const data = await response.json();
    
    if (data.success) {
      console.log('CPU:', data.data.cpu_percent + '%');
      console.log('Vidéos:', data.data.video_count);
    }
  } catch (error) {
    console.error('Erreur API:', error);
  }
}

async function controlPlayer(action) {
  try {
    const response = await fetch('<?= $api_base ?>', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        action: 'player_control',
        action: action
      })
    });
    
    const data = await response.json();
    console.log(data.message);
  } catch (error) {
    console.error('Erreur:', error);
  }
}
                </div>
            </div>
        </div>
    </main>

    <script src="assets/js/app.js"></script>
    <script>
        async function testEndpoint(action, method = 'GET') {
            const resultsDiv = document.getElementById('test-results');
            const outputDiv = document.getElementById('test-output');
            
            try {
                const url = '<?= $api_base ?>?action=' + action;
                const response = await fetch(url, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });
                
                const data = await response.json();
                
                outputDiv.innerHTML = `
<strong>Status:</strong> ${response.status}
<strong>Response:</strong>
${JSON.stringify(data, null, 2)}
                `;
                
                resultsDiv.classList.remove('hidden');
                resultsDiv.scrollIntoView({ behavior: 'smooth' });
                
            } catch (error) {
                outputDiv.innerHTML = `
<strong>Erreur:</strong>
${error.message}
                `;
                resultsDiv.classList.remove('hidden');
            }
        }
        
        async function testPlayerControl(action) {
            const resultsDiv = document.getElementById('test-results');
            const outputDiv = document.getElementById('test-output');
            
            try {
                const response = await fetch('<?= $api_base ?>', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        action: 'player_control',
                        action: action
                    })
                });
                
                const data = await response.json();
                
                outputDiv.innerHTML = `
<strong>Action:</strong> ${action}
<strong>Status:</strong> ${response.status}
<strong>Response:</strong>
${JSON.stringify(data, null, 2)}
                `;
                
                resultsDiv.classList.remove('hidden');
                resultsDiv.scrollIntoView({ behavior: 'smooth' });
                
            } catch (error) {
                outputDiv.innerHTML = `
<strong>Erreur:</strong>
${error.message}
                `;
                resultsDiv.classList.remove('hidden');
            }
        }
    </script>
</body>
</html>